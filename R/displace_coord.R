#' Displace survey coordinates to protect respondents
#'
#' Moves every survey location in a random direction by a random distance,
#' following the rule of the Demographic and Health Surveys (DHS): urban
#' locations by up to 2 km, rural ones by up to 5 km, and a random 1% of the
#' rural ones by up to 10 km. Households that share a location move together.
#'
#' Run it before sharing a file with coordinates, or before any variable is
#' computed from them when the team itself should not hold the true
#' locations. Variables computed afterwards (weather extremes, distances,
#' controls) are then based on the displaced locations: the error this adds
#' is small for smooth climate fields and division averages, and larger for
#' short distances such as to the nearest road.
#'
#' @section Where a location may land:
#' Three options restrict or adapt the displacement, alone or together:
#' * `boundaries`: a location stays inside the administrative division it
#'   started in, so division-level variables are not affected.
#' * `water`: a location never lands in a water body, where no household
#'   lives and where extracted values (temperature over a lake, distance to
#'   the shore) would be wrong. This costs no privacy, since nobody lives
#'   there anyway. Use `min_water_area` to keep only large water bodies.
#' * `population` and `min_people`: the limit of each location becomes the
#'   radius within which at least `min_people` people live (inside its
#'   division and outside water, when those are given), between
#'   `min_scale` and `max_scale` times its DHS limit. Sparse places then
#'   move further and dense ones less, so every respondent hides among about
#'   the same number of people. With the default `min_scale = 1` the DHS
#'   limits are a floor, as many data agreements require; a smaller
#'   `min_scale` lets dense places move less than the DHS rule. A location
#'   that reaches `max_scale` holds fewer people than asked, and a warning
#'   says how many.
#'
#' @section What changes in the table:
#' * The coordinate columns hold the displaced coordinates.
#' * Location identifiers built from coordinates ([prepare_coord()] with
#'   `id_rule = "coordinates"`) are rebuilt from the displaced ones, since the
#'   old identifiers would reveal the true locations.
#' * The context records the rule, the limits and the options used (not the
#'   seed). Labels, the Stata codebook and printed tables then say that the
#'   coordinates are displaced, and later tables built from these locations
#'   carry the record.
#'
#' Keep `seed` private: with the seed, the displacement can be undone.
#'
#' @param x A survey from [prepare_coord()], or a data frame with coordinates
#'   in longitude and latitude (WGS84).
#' @param lat,lon <[`tidy-select`][dplyr::dplyr_tidy_select]> The coordinate
#'   columns; read from `x` when it comes from [prepare_coord()].
#' @param type <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional column
#'   saying whether each location is `"urban"` or `"rural"` (also `"U"`,
#'   `"R"`, `TRUE` for urban). When not given, every location is treated as
#'   rural, the larger displacement.
#' @param urban,rural,rural_far Maximum displacement in metres.
#' @param share_far Share of rural locations displaced by up to `rural_far`.
#' @param boundaries Optional administrative divisions (`SpatVector` of
#'   polygons) a location must stay inside.
#' @param water Optional water bodies (`SpatVector` of polygons, such as
#'   lakes and reservoirs) a location must not land in.
#' @param min_water_area Smallest water body kept from `water`, in km2.
#' @param population Optional raster of people per cell (`SpatRaster` or a
#'   path), such as WorldPop counts. Requires `min_people`.
#' @param min_people Number of people that must live within the limit of
#'   each location.
#' @param min_scale,max_scale With `population`, the smallest and largest
#'   limit, as multiples of the DHS limit of each location.
#' @param seed Optional seed, for a displacement that can be repeated. Keep it
#'   private.
#' @param max_tries Draws allowed per location to land in its allowed area.
#'
#' @return `x` with displaced coordinates, as a `c4e_tbl`.
#'
#' @seealso [prepare_coord()]
#' @export
#'
#' @examples
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon, id = hhid)
#'
#' adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
#' displaced <- displace_coord(coord, boundaries = adm_div, seed = 1)
#'
#' # how far each location moved, in km
#' moved <- terra::distance(as.matrix(coord[c("lon", "lat")]),
#'                          as.matrix(displaced[c("lon", "lat")]),
#'                          lonlat = TRUE, pairwise = TRUE) / 1000
#' summary(moved)
#' c4e_labels(displaced)
#'
#' # a lake to avoid, and a radius holding at least 5,000 people
#' lake <- terra::buffer(terra::vect(cbind(30.6, -0.4), crs = "EPSG:4326"), 8000)
#' people <- terra::rast(adm_div, resolution = 0.01)
#' terra::values(people) <- 50 * terra::values(terra::cellSize(people, unit = "km"))
#' displaced <- displace_coord(coord, boundaries = adm_div, water = lake,
#'                             population = people, min_people = 5000, seed = 1)
displace_coord <- function(x, lat = NULL, lon = NULL, type = NULL,
                           urban = 2000, rural = 5000, rural_far = 10000,
                           share_far = 0.01, boundaries = NULL,
                           water = NULL, min_water_area = 0,
                           population = NULL, min_people = NULL,
                           min_scale = 1, max_scale = 3,
                           seed = NULL, max_tries = 100) {
    started <- Sys.time()
    for (arg in c("urban", "rural", "rural_far")) {
        value <- get(arg)
        if (!is.numeric(value) || length(value) != 1 || is.na(value) || value < 0) {
            cli::cli_abort("{.arg {arg}} must be one distance in metres, 0 or more.")
        }
    }
    if (!is.numeric(share_far) || length(share_far) != 1 || share_far < 0 || share_far > 1) {
        cli::cli_abort("{.arg share_far} must be a number between 0 and 1.")
    }
    if (!is.null(population)) {
        population <- check_population(population, min_people, min_scale, max_scale)
    }
    if (!is.null(seed)) {
        restore_seed <- local_seed(seed)
        on.exit(restore_seed(), add = TRUE)
    }

    meta <- c4e_meta(x) %||% empty_meta()
    data <- tibble::as_tibble(x)
    lat_name <- optional_column(data, rlang::enquo(lat), "lat") %||% meta$survey$lat
    lon_name <- optional_column(data, rlang::enquo(lon), "lon") %||% meta$survey$lon
    if (is.null(lat_name) || is.null(lon_name)) {
        cli::cli_abort("Give {.arg lat} and {.arg lon}, or a survey from
                        {.fn prepare_coord}.")
    }
    type_name <- optional_column(data, rlang::enquo(type), "type")

    # one displacement per location: households at the same place move together
    location <- vctrs::vec_group_id(data[c(lon_name, lat_name)])
    first <- !duplicated(location)
    lon0 <- data[[lon_name]][first]
    lat0 <- data[[lat_name]][first]
    known <- !is.na(lon0) & !is.na(lat0)
    if (any(abs(lat0[known]) > 90) || any(abs(lon0[known]) > 360)) {
        cli::cli_abort("The coordinates must be longitude and latitude in degrees.")
    }
    urban_loc <- if (is.null(type_name)) {
        c4e_inform("No {.arg type} given: every location is displaced as rural
                    (up to {rural / 1000} km).")
        rep(FALSE, length(lon0))
    } else {
        is_urban(data[[type_name]][first])
    }
    limit <- ifelse(urban_loc, urban, rural)
    rural_idx <- which(!urban_loc & known)
    n_far <- round(share_far * length(rural_idx))
    if (n_far > 0) {
        far <- rural_idx[sample.int(length(rural_idx), n_far)]
        limit[far] <- rural_far
    }

    division <- rep(NA_integer_, length(lon0))
    if (!is.null(boundaries)) {
        boundaries <- terra::project(as_spat_vector(boundaries), "EPSG:4326")
        division <- division_of(lon0, lat0, boundaries)
    }
    if (!is.null(water)) {
        water <- water_bodies(water, min_water_area)
        n_wet <- sum(in_water(lon0[known], lat0[known], water))
        if (n_wet > 0) {
            cli::cli_warn("{n_wet} true location{?s} {?lies/lie} in {.arg water};
                           {?it is/they are} moved out of it.")
        }
    }

    adapted <- NULL
    if (!is.null(population)) {
        adapted <- people_limits(lon0, lat0, limit, known, division, boundaries,
                                 water, population, min_people, min_scale, max_scale)
        limit <- adapted$limit
    }

    lon1 <- lon0
    lat1 <- lat0
    todo <- which(known)
    for (try in seq_len(max_tries)) {
        if (length(todo) == 0) break
        moved <- move_points(lon0[todo], lat0[todo], limit[todo])
        lon1[todo] <- moved$lon
        lat1[todo] <- moved$lat
        stays <- rep(TRUE, length(todo))
        if (!is.null(boundaries)) {
            # a location outside every division has no division to stay in
            landed <- division_of(lon1[todo], lat1[todo], boundaries)
            stays <- is.na(division[todo]) |
                (!is.na(landed) & landed == division[todo])
        }
        if (!is.null(water)) {
            stays <- stays & !in_water(lon1[todo], lat1[todo], water)
        }
        todo <- todo[!stays]
    }
    if (length(todo) > 0) {
        n_left <- length(todo)
        cli::cli_abort(c("{n_left} location{?s} could not be placed in {?its/their}
                          allowed area in {max_tries} draws.",
                         "i" = "Check that {.arg boundaries} cover the survey and that
                                {.arg water} leaves land nearby, or raise
                                {.arg max_tries}."))
    }

    data[[lon_name]] <- lon1[location]
    data[[lat_name]] <- lat1[location]
    if (identical(meta$id_rule, "coordinates") && identical(meta$key, "ID") &&
        "ID" %in% names(data)) {
        data$ID <- coordinate_id(data[[lon_name]], data[[lat_name]], 5)
    }

    record <- list(rule = "DHS", urban = urban, rural = rural, rural_far = rural_far,
                   share_far = share_far, n_locations = sum(known),
                   n_far = n_far, typed = !is.null(type_name),
                   within_boundaries = !is.null(boundaries),
                   off_water = !is.null(water),
                   population = adapted$record)
    survey <- meta$survey %||% list(lon = lon_name, lat = lat_name)
    survey$displaced <- record
    meta <- modify_meta(meta, list(survey = survey))
    meta <- c4e_record(meta, "displace_coord",
                       list(urban = urban, rural = rural, rural_far = rural_far,
                            share_far = share_far,
                            boundaries = if (!is.null(boundaries)) "given",
                            water = if (!is.null(water)) "given",
                            population = if (!is.null(population)) "given",
                            min_people = min_people,
                            min_scale = if (!is.null(population)) min_scale,
                            max_scale = if (!is.null(population)) max_scale),
                       started)
    new_c4e_tbl(data, meta)
}

#' Move points by a random distance up to `limit` metres in a random
#' direction
#'
#' The distance is drawn uniformly between 0 and the limit, as in the DHS
#' rule; on the sphere, a metre of latitude is the same everywhere and a
#' metre of longitude shrinks with the cosine of the latitude (accurate to a
#' fraction of a percent at these distances).
#' @noRd
move_points <- function(lon, lat, limit) {
    angle <- stats::runif(length(lon), 0, 2 * pi)
    distance <- stats::runif(length(lon), 0, limit)
    metres_per_degree <- 111320
    list(lat = lat + distance * cos(angle) / metres_per_degree,
         lon = lon + distance * sin(angle) /
             (metres_per_degree * cos(lat * pi / 180)))
}

#' The division (row of `boundaries`) each point falls in; NA outside
#' @noRd
division_of <- function(lon, lat, boundaries) {
    points <- terra::vect(cbind(lon, lat), crs = "EPSG:4326")
    if (!terra::same.crs(points, boundaries)) {
        points <- terra::project(points, terra::crs(boundaries))
    }
    hits <- terra::relate(points, boundaries, "intersects")
    apply(hits, 1, \(row) if (any(row)) which(row)[1] else NA_integer_)
}

is_urban <- function(type) {
    if (is.logical(type)) return(!is.na(type) & type)
    value <- tolower(trimws(as.character(type)))
    known <- value %in% c("urban", "u", "rural", "r")
    if (!all(known | is.na(value))) {
        bad <- unique(type[!known & !is.na(value)])
        cli::cli_abort("{.arg type} must be urban or rural; found {.val {bad}}.",
                       call = rlang::caller_env(2))
    }
    value %in% c("urban", "u")
}

# ==== Water and population ================================================ ----

#' The polygons of `water` of at least `min_area` km2, in WGS84
#' @noRd
water_bodies <- function(water, min_area, call = rlang::caller_env()) {
    water <- as_spat_vector(water)
    if (terra::geomtype(water) != "polygons") {
        cli::cli_abort("{.arg water} must be polygons, such as lakes.", call = call)
    }
    water <- terra::project(water, "EPSG:4326")
    water[terra::expanse(water, unit = "km") >= min_area]
}

in_water <- function(lon, lat, water) {
    if (nrow(water) == 0 || length(lon) == 0) return(rep(FALSE, length(lon)))
    points <- terra::vect(cbind(lon, lat), crs = "EPSG:4326")
    rowSums(terra::relate(points, water, "intersects")) > 0
}

check_population <- function(population, min_people, min_scale, max_scale,
                             call = rlang::caller_env()) {
    if (is.character(population)) population <- terra::rast(population)
    if (!inherits(population, "SpatRaster") || terra::nlyr(population) != 1) {
        cli::cli_abort("{.arg population} must be one raster layer of people per cell.",
                       call = call)
    }
    if (!is.numeric(min_people) || length(min_people) != 1 || is.na(min_people) ||
        min_people <= 0) {
        cli::cli_abort("With {.arg population}, give {.arg min_people}, a number of
                        people above 0.", call = call)
    }
    if (!is.numeric(min_scale) || !is.numeric(max_scale) || length(min_scale) != 1 ||
        length(max_scale) != 1 || min_scale <= 0 || max_scale < min_scale) {
        cli::cli_abort("{.arg min_scale} and {.arg max_scale} must be numbers with
                        0 < {.arg min_scale} <= {.arg max_scale}.", call = call)
    }
    population
}

#' The limit of each location that holds `min_people`, and the record
#'
#' The raster is cropped once to the reach of the survey, so each search
#' reads only a small window.
#' @noRd
people_limits <- function(lon, lat, limit, known, division, boundaries, water,
                          population, min_people, min_scale, max_scale,
                          call = rlang::caller_env()) {
    idx <- which(known & limit > 0)
    if (length(idx) > 0) {
        reach <- terra::buffer(terra::vect(cbind(lon[idx], lat[idx]), crs = "EPSG:4326"),
                               max_scale * limit[idx])
        reach <- terra::project(reach, terra::crs(population))
        population <- tryCatch(
            terra::crop(population, reach, snap = "out"),
            error = \(e) cli::cli_abort("{.arg population} does not cover the survey
                                        locations.", call = call))
        c4e_inform("Finding the radius that holds {round(min_people)} people for
                    {length(idx)} location{?s}.")
    }
    old <- limit
    for (i in idx) {
        own <- if (!is.na(division[i])) boundaries[division[i]]
        limit[i] <- people_radius(lon[i], lat[i], limit[i], own, water, population,
                                  min_people, min_scale, max_scale)
    }
    n_capped <- sum(limit[idx] >= max_scale * old[idx])
    if (n_capped > 0) {
        cli::cli_warn("{n_capped} location{?s} reached {.arg max_scale} = {max_scale}
                       with fewer than {round(min_people)} people within {?its/their} limit.",
                      call = call)
    }
    record <- list(min_people = min_people, min_scale = min_scale,
                   max_scale = max_scale,
                   n_widened = sum(limit[idx] > old[idx]),
                   n_narrowed = sum(limit[idx] < old[idx]),
                   n_capped = n_capped)
    list(limit = limit, record = record)
}

#' The radius within which `min_people` live, inside the division `own` and
#' outside `water`, between `min_scale` and `max_scale` times `limit`
#'
#' The number of people grows with the radius, so the root is unique.
#' @noRd
people_radius <- function(lon, lat, limit, own, water, population, min_people,
                          min_scale, max_scale) {
    point <- terra::vect(cbind(lon, lat), crs = "EPSG:4326")
    people <- function(r) {
        area <- terra::buffer(point, r, quadsegs = 30)
        if (!is.null(own)) area <- terra::intersect(area, own)
        if (!is.null(water) && nrow(water) > 0 && nrow(area) > 0) {
            area <- terra::erase(area, water)
        }
        if (nrow(area) == 0) return(0)
        if (!terra::same.crs(area, population)) {
            area <- terra::project(area, terra::crs(population))
        }
        sum(terra::extract(population, area, fun = sum, exact = TRUE,
                           na.rm = TRUE, ID = FALSE)[[1]])
    }
    lower <- min_scale * limit
    upper <- max_scale * limit
    gap <- function(r) people(r) - min_people
    if (gap(lower) >= 0) return(lower)
    if (gap(upper) <= 0) return(upper)
    stats::uniroot(gap, c(lower, upper), tol = 10)$root
}

#' Set the seed and return a function restoring the previous random state
#' @noRd
local_seed <- function(seed) {
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    old <- if (had_seed) get(".Random.seed", envir = globalenv())
    set.seed(seed)
    function() {
        if (had_seed) {
            assign(".Random.seed", old, envir = globalenv())
        } else {
            rm(".Random.seed", envir = globalenv())
        }
    }
}
