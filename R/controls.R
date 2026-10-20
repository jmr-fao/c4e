# The two control wrappers (plan §12): static_controls() for layers with
# no time dimension, time_varying_controls() for yearly layers and climate
# normals. Both return one row per household.

# ==== Shared machinery ===================================================== ----

#' The kind of each control layer: given, recorded, or guessed from its name
#' @noRd
layer_kind <- function(layer, name, kind) {
    given <- if (!is.null(names(kind))) kind[[name]] else kind
    if (!is.null(given)) return(given)
    recorded <- stored_raster_meta(layer)$kind
    if (!is.null(recorded)) return(recorded)
    if (any(terra::is.factor(layer))) return("categorical")
    if (grepl("aez|zone|urca|land_?cover|soil|class|biome|koppen", name,
              ignore.case = TRUE)) {
        return("categorical")
    }
    if (grepl("^pop|population|count|livestock", name, ignore.case = TRUE)) {
        return("count")
    }
    "continuous"
}

#' A named list of control layers, each a SpatRaster
#' @noRd
control_layers <- function(layers, call = rlang::caller_env()) {
    if (inherits(layers, "SpatRaster")) {
        layers <- list(layers)
        names(layers) <- names(layers[[1]])[1]
    }
    if (!is.list(layers) || !rlang::is_named(layers)) {
        cli::cli_abort("{.arg layers} must be a named list of rasters, e.g.
                        {.code list(elevation = dem, aez = zones)}.", call = call)
    }
    purrr::map(layers, \(layer) if (is.character(layer)) terra::rast(layer) else layer)
}

summary_fn <- function(kind) {
    switch(kind, categorical = "mode", count = "sum", "mean")
}

#' Values of one raster at each location (or division): a tibble with the
#' location key as `..key` and one column per layer of the raster
#' @noRd
control_values <- function(layer, name, kind, points, key, buffer, boundaries) {
    layer <- read_climate(layer, variable = name, kind = kind)
    if (!is.null(boundaries)) {
        values <- extract_by_poly(layer, boundaries, fn_agg = summary_fn(kind))
        key <- "ID_adm_div"
    } else if (buffer > 0) {
        values <- extract_by_coord(layer, points, buffer = buffer, fn = summary_fn(kind))
    } else {
        values <- extract_by_coord(layer, points)
    }
    values <- tibble::as_tibble(values)
    attributes <- names(terra::values(boundaries %||% points))
    value_cols <- setdiff(names(values), c(attributes, "x_cell", "y_cell"))
    out <- values[c(key, value_cols)]
    names(out)[1] <- "..key"
    out$..key <- as.character(out$..key)
    out
}

buffer_suffix <- function(buffer) {
    if (buffer > 0) paste0("_", format(buffer / 1000, trim = TRUE), "km") else ""
}

#' A control column's registry entry
#' @noRd
control_entry <- function(name, kind, buffer, period = "static", stat = NULL,
                          unit = NULL) {
    list(kind = "par", variable = name,
         stat = stat %||% (if (buffer > 0) summary_fn(kind) else "value"),
         buffer = if (buffer > 0) buffer, period = period, unit = unit)
}

#' The household-level table of a control wrapper
#'
#' `values` is keyed by `..key`, the location or division of each
#' household (`by`); `point_values` by `..key`, the household's own location.
#' @noRd
control_output <- function(locations, values, entries, by, fn, args, started,
                           extra = NULL, point_values = NULL) {
    meta <- c4e_meta(locations)
    key <- meta$survey$id %||% meta$key
    loc <- tibble::as_tibble(locations)
    loc$..key <- as.character(loc[[by]])
    loc$..loc <- as.character(loc[[meta$key]])
    out <- loc[unique(c(key, extra, "..key", "..loc"))]
    out <- out[!duplicated(out[unique(c(key, extra))]), , drop = FALSE]
    out <- dplyr::left_join(out, values, by = intersect(c("..key", extra), names(values)))
    if (!is.null(point_values)) {
        out <- dplyr::left_join(out, dplyr::rename(point_values, ..loc = "..key"),
                                by = "..loc")
    }
    out$..key <- NULL
    out$..loc <- NULL
    out <- dplyr::arrange(out, dplyr::across(dplyr::all_of(unique(c(key, extra)))))

    new_meta <- empty_meta()
    new_meta$key <- key
    new_meta$shape <- "summary"
    new_meta$survey <- meta$survey
    new_meta$survey_cols <- intersect(c(meta$survey$id, extra), names(out))
    new_meta$crs <- meta$crs
    new_meta$label <- meta$label
    new_meta$indicators <- entries[intersect(names(entries), names(out))]
    new_meta$history <- meta$history
    new_meta <- c4e_record(new_meta, fn, args, started)
    new_c4e_tbl(out, new_meta)
}

# ==== static_controls() ===================================================== ----

#' Location controls that do not change over time, in one call
#'
#' Summarises layers with no time dimension at each household's location:
#' elevation and the terrain measures derived from it, agro-ecological
#' zones, land cover, soil, and distances to roads, markets, borders or
#' water. One row per household.
#'
#' Each layer is treated by its kind: continuous layers are averaged,
#' counts summed and categorical layers (zones, classes) take their most
#' frequent value, so a category is never averaged. The kind is read from
#' [read_climate()], or guessed from the layer's name (`aez`, `zone`,
#' `land_cover`, `soil`, `class` are categorical; `pop` is a count), or
#' given with `kind`.
#'
#' With `buffer`, each radius (in metres) adds one set of columns, named
#' with the radius: `elevation_20km`. A radius of 0 is the value of the
#' location's own cell. With an `elevation` layer, `terrain` adds slope (in
#' degrees), the terrain ruggedness index and roughness, computed from the
#' eight neighbouring cells; cells at the edge of the raster, where these
#' are missing, are filled from their neighbours when `fill_missing` is set
#' in `control` (the default). With `boundaries`, each household gets the
#' summary of its division instead; distances stay at its own location.
#'
#' The chain: [prepare_coord()], [georef_coord()], [read_climate()],
#' [fill_missing_rast()], [extract_by_coord()] (or [extract_by_poly()]) and
#' [calc_nearest_distance()].
#'
#' @param layers A named list of single-layer rasters (or file paths), e.g.
#'   `list(elevation = dem, aez = zones)`.
#' @param lat,lon,id <[`tidy-select`][dplyr::dplyr_tidy_select]> Survey
#'   columns: coordinates (found by name when left out) and household
#'   identifier. Not needed after [prepare_coord()].
#' @param kind Optional named character vector of layer kinds:
#'   `"continuous"`, `"count"` or `"categorical"`.
#' @param buffer Radii in metres; 0 is the location's own cell.
#' @param terrain Terrain measures computed from an `elevation` layer; any of
#'   `"slope"`, `"TRI"`, `"roughness"`, `"aspect"`, `"TPI"`, or `NULL`.
#' @param distance_to Optional named list of `SpatVector`s; each adds
#'   `dist_<name>_km`, the distance to its nearest feature.
#' @param boundaries Optional administrative divisions to summarise over.
#' @param control Further options, see [controls_control()].
#' @inheritParams weather_extremes
#'
#' @return A `c4e_tbl` with one row per household.
#'
#' @seealso [time_varying_controls()], [extract_by_coord()]
#' @export
#'
#' @examples
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' template <- terra::rast(system.file("extdata", "tmax_daily.tif",
#'                                     package = "c4e"))[[1]]
#' dem <- terra::rast(template, vals = seq(500, 1550, length.out = 36))
#'
#' static_controls(survey, list(elevation = dem), id = hhid,
#'                 buffer = c(0, 20000))
static_controls <- function(survey, layers, lat = NULL, lon = NULL, id = NULL,
                            kind = NULL, buffer = 0,
                            terrain = c("slope", "TRI", "roughness"),
                            distance_to = NULL, boundaries = NULL,
                            control = controls_control()) {
    started <- Sys.time()
    cols <- column_names(rlang::enquo(lat), rlang::enquo(lon), rlang::enquo(id),
                         rlang::quo(NULL))
    if (is_survey_list(survey)) {
        return(map_surveys(survey, \(one, name) {
            control$label <- name
            static_controls(one, layers, lat = !!cols$lat, lon = !!cols$lon,
                            id = !!cols$id, kind = kind, buffer = buffer,
                            terrain = terrain, distance_to = distance_to,
                            boundaries = boundaries, control = control)
        }))
    }
    if (isFALSE(control$verbose)) {
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
    }
    env <- environment()
    stage <- function(msg) c4e_progress_step(msg, .envir = env)

    layers <- control_layers(layers)
    several <- names(layers)[vapply(layers, terra::nlyr, numeric(1)) > 1]
    if (length(several) > 0) {
        cli::cli_abort(c("Static layers have one layer each; {.field {several}}
                          {?has/have} more.",
                         "i" = "For yearly layers, use {.fn time_varying_controls}."))
    }
    if (!is.numeric(buffer) || any(buffer < 0)) {
        cli::cli_abort("{.arg buffer} must be distances in metres, 0 for the
                        location's own cell.")
    }
    if (!is.null(distance_to) && (!is.list(distance_to) || !rlang::is_named(distance_to))) {
        cli::cli_abort("{.arg distance_to} must be a named list of
                        {.cls SpatVector}s, e.g. {.code list(road = roads)}.")
    }
    kinds <- purrr::imap_chr(layers, \(layer, name) layer_kind(layer, name, kind))
    if (!is.null(terrain) && "elevation" %in% names(layers)) {
        measures <- terra::terrain(layers$elevation, v = terrain, neighbors = 8,
                                   unit = "degrees")
        for (measure in terrain) {
            layers[[measure]] <- measures[[measure]]
            kinds[[measure]] <- "continuous"
        }
    }
    if (isTRUE(control$fill_missing)) {
        layers <- purrr::imap(layers, \(layer, name) {
            fun <- if (kinds[[name]] == "categorical") "modal" else "mean"
            filled <- fill_missing_rast(layer, fun = fun)
            names(filled) <- names(layer)
            filled
        })
    }

    locations <- survey_locations(survey, cols)
    points <- georef_coord(locations)
    key <- c4e_meta(locations)$key
    by <- key
    if (!is.null(boundaries)) {
        locations <- locations_in_divisions(locations, points, boundaries)
        by <- "ID_adm_div"
    }

    radii <- if (is.null(boundaries)) buffer else 0
    inform_spec("static_controls", list(variable = "static layers"), c(
        paste0("layers: ", paste0(names(layers), " (", kinds, ")", collapse = ", ")),
        if (is.null(boundaries)) {
            paste0("radii: ", paste(radii / 1000, collapse = ", "), " km")
        } else {
            "summarised by division"
        },
        if (!is.null(distance_to)) {
            paste0("distances to: ", paste(names(distance_to), collapse = ", "))
        }
    ), locations)
    if (isTRUE(control$dry_run)) {
        inform_plan(c(
            paste0("extract ", length(layers), " layers at ",
                   nrow(terra::unique(points)), " locations, ", length(radii),
                   " radi", if (length(radii) == 1) "us" else "i"),
            if (!is.null(distance_to)) paste0(length(distance_to), " distances")
        ))
        return(invisible(NULL))
    }

    stage("Extracting {length(layers)} layer{?s}")
    values <- NULL
    entries <- list()
    for (radius in radii) {
        for (name in names(layers)) {
            one <- suppressMessages(control_values(layers[[name]], name, kinds[[name]],
                                                   points, key, radius, boundaries))
            column <- paste0(name, buffer_suffix(radius))
            names(one) <- c("..key", column)
            entries[[column]] <- control_entry(name, kinds[[name]], radius)
            values <- if (is.null(values)) one else dplyr::full_join(values, one, by = "..key")
        }
    }

    distances <- NULL
    if (!is.null(distance_to)) {
        stage("Computing distances")
        distances <- tibble::tibble(..key = as.character(terra::values(points)[[key]]))
        for (name in names(distance_to)) {
            column <- paste0("dist_", name, "_km")
            nearest <- suppressMessages(
                calc_nearest_distance(points, as_spat_vector(distance_to[[name]])))
            distances[[column]] <- nearest$dist_nearest_km
            entries[[column]] <- list(kind = "par", variable = name, stat = "distance",
                                      unit = "km", period = "static")
        }
    }

    control_output(locations, values, entries, by, "static_controls",
                   list(buffer = buffer, terrain = terrain, kind = kind,
                        distance_to = names(distance_to),
                        fill_missing = control$fill_missing),
                   started, point_values = distances)
}

# ==== time_varying_controls() =============================================== ----

#' Location controls in the survey year, in one call
#'
#' Takes, for each household, the layer of the year that matches its
#' survey: population, night lights, land cover by year. With `climate`, it
#' adds the climate normals of the `years` before the survey year. One row
#' per household and survey year.
#'
#' `match` decides which yearly layer serves a survey year: the same year,
#' the previous one (to use only data from before the interview) or the
#' nearest available. The year used is kept in `<layer>_year`, and the
#' labels say which rule was applied. Count layers (population) also get
#' `<layer>_density`, per square kilometre of the cells summed; layers named
#' in `log` get `log_<layer>`, the log of one plus the value.
#'
#' The normals use [calc_par()] on the series from `years` years before the
#' survey year to the end of the year before it; when the data cover fewer
#' years, a message says which.
#'
#' @param layers A named list of rasters with one layer per year, dated with
#'   `terra::time()`; e.g. `list(pop = worldpop)`.
#' @param year <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional survey
#'   column holding the survey year, instead of the interview date.
#' @param match `"same_year"`, `"previous_year"` or `"nearest"`.
#' @param climate Optional named list of climate rasters (paths or
#'   `SpatRaster`s) for the normals, e.g. `list(pre = chirps)`.
#' @param years Number of years before the survey year for the normals.
#' @param stats Statistics of the normals: any of `"mean"`, `"sd"`, `"cv"`,
#'   `"min"`, `"max"`, `"median"`, `"sum"`.
#' @param density Add the density of count layers.
#' @param log Names of layers to add as `log(1 + value)`.
#' @param buffer A radius in metres; 0 is the location's own cell.
#' @inheritParams weather_extremes
#' @inheritParams static_controls
#'
#' @return A `c4e_tbl` with one row per household and survey year.
#'
#' @seealso [static_controls()], [calc_par()]
#' @export
#'
#' @examples
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' survey$interview <- as.Date(survey$interview)
#' template <- terra::rast(system.file("extdata", "tmax_daily.tif",
#'                                     package = "c4e"))[[1]]
#' pop <- terra::rast(template, nlyrs = 3, vals = rep(c(100, 200, 300), each = 36))
#' terra::time(pop) <- as.Date(c("2021-01-01", "2022-01-01", "2023-01-01"))
#'
#' time_varying_controls(survey, list(pop = pop), id = hhid,
#'                       interview = interview, match = "previous_year")
time_varying_controls <- function(survey, layers = NULL, lat = NULL, lon = NULL,
                                  id = NULL, interview = NULL, year = NULL,
                                  match = c("same_year", "previous_year", "nearest"),
                                  climate = NULL, years = 30,
                                  stats = c("mean", "sd", "cv"), density = TRUE,
                                  log = "nightlight", buffer = 0, kind = NULL,
                                  boundaries = NULL, control = controls_control()) {
    started <- Sys.time()
    match <- rlang::arg_match(match)
    cols <- column_names(rlang::enquo(lat), rlang::enquo(lon), rlang::enquo(id),
                         rlang::enquo(interview))
    year_col <- rlang::enquo(year)
    year_col <- if (rlang::quo_is_null(year_col)) NULL else rlang::as_name(year_col)
    if (is_survey_list(survey)) {
        return(map_surveys(survey, \(one, name) {
            control$label <- name
            time_varying_controls(one, layers, lat = !!cols$lat, lon = !!cols$lon,
                                  id = !!cols$id, interview = !!cols$interview,
                                  year = !!year_col, match = match, climate = climate,
                                  years = years, stats = stats, density = density,
                                  log = log, buffer = buffer, kind = kind,
                                  boundaries = boundaries, control = control)
        }))
    }
    if (isFALSE(control$verbose)) {
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
    }
    env <- environment()
    stage <- function(msg) c4e_progress_step(msg, .envir = env)
    if (is.null(layers) && is.null(climate)) {
        cli::cli_abort("Give {.arg layers}, {.arg climate} or both.")
    }
    if (!is.numeric(buffer) || length(buffer) != 1 || buffer < 0) {
        cli::cli_abort("{.arg buffer} must be one distance in metres, 0 for the
                        location's own cell.")
    }
    fns <- stats::setNames(purrr::map(stats, normal_function), stats)

    locations <- survey_locations(survey, cols)
    points <- georef_coord(locations)
    meta <- c4e_meta(locations)
    key <- meta$key
    loc <- tibble::as_tibble(locations)
    if (!is.null(year_col)) {
        loc$survey_year <- as.integer(loc[[year_col]])
    } else {
        interview_col <- meta$survey$interview
        if (is.null(interview_col)) {
            cli::cli_abort("Give {.arg interview} or {.arg year}, to know each
                            household's survey year.")
        }
        loc$survey_year <- as.integer(format(as.Date(loc[[interview_col]]), "%Y"))
    }
    locations <- new_c4e_tbl(loc, meta)
    by <- key
    if (!is.null(boundaries)) {
        locations <- locations_in_divisions(locations, points, boundaries)
        by <- "ID_adm_div"
    }
    survey_years <- sort(unique(stats::na.omit(locations$survey_year)))

    layers <- if (!is.null(layers)) control_layers(layers) else list()
    kinds <- purrr::imap_chr(layers, \(layer, name) layer_kind(layer, name, kind))
    served <- purrr::imap(layers, \(layer, name) {
        layer_years(layer, name, survey_years, match)
    })

    inform_spec("time_varying_controls", list(variable = "yearly layers"), c(
        if (length(layers) > 0) {
            paste0("layers: ", paste0(names(layers), " (", match, ")", collapse = ", "))
        },
        if (!is.null(climate)) {
            paste0("normals of ", paste(names(climate), collapse = ", "), " over the ",
                   years, " years before the survey")
        },
        paste0("survey years: ", paste(survey_years, collapse = ", "))
    ), locations)
    if (isTRUE(control$dry_run)) {
        inform_plan(c(
            if (length(layers) > 0) paste0("extract ", length(layers), " yearly layers"),
            if (!is.null(climate)) paste0("normals of ", length(climate), " climate variables"),
            paste0("one row per household and survey year (", length(survey_years),
                   " years)")
        ))
        return(invisible(NULL))
    }

    parts <- list()
    entries <- list()
    if (length(layers) > 0) {
        stage("Extracting {length(layers)} yearly layer{?s}")
    }
    for (name in names(layers)) {
        part <- yearly_layer_values(layers[[name]], name, kinds[[name]], served[[name]],
                                    match, density, log, points, key, buffer, boundaries)
        parts[[name]] <- part$values
        entries <- c(entries, part$entries)
    }
    if (!is.null(climate)) {
        stage("Computing climate normals")
        for (name in names(climate)) {
            normals <- climate_normals(climate[[name]], name, survey_years, years, fns,
                                       points, key, boundaries)
            parts[[paste0("climate_", name)]] <- normals$values
            entries <- c(entries, normals$entries)
        }
    }
    values <- purrr::reduce(parts, \(a, b) {
        dplyr::full_join(a, b, by = c("..key", "survey_year"))
    })

    control_output(locations, values, entries, by, "time_varying_controls",
                   list(match = match, years = years, stats = stats, buffer = buffer,
                        layers = names(layers), climate = names(climate)),
                   started, extra = "survey_year")
}

layer_years_of <- function(layer) {
    if (!terra::has.time(layer)) {
        years <- suppressWarnings(as.integer(substr(names(layer), 1, 4)))
        if (anyNA(years)) {
            cli::cli_abort("A yearly layer needs dates: set them with
                            {.code terra::time(x) <- dates}.")
        }
        return(years)
    }
    as.integer(format(as.Date(terra::time(layer)), "%Y"))
}

#' Which layer year serves each survey year
#' @noRd
layer_years <- function(layer, name, survey_years, match) {
    available <- layer_years_of(layer)
    chosen <- switch(match,
        same_year     = ifelse(survey_years %in% available, survey_years, NA_integer_),
        previous_year = ifelse((survey_years - 1L) %in% available, survey_years - 1L,
                               NA_integer_),
        # the closest year, the earlier one on a tie
        nearest       = vapply(survey_years, \(y) {
            distance <- abs(available - y) + (available > y) * 0.1
            available[which.min(distance)]
        }, integer(1)))
    missing <- survey_years[is.na(chosen)]
    if (length(missing) > 0) {
        first <- min(available)
        last <- max(available)
        cli::cli_warn(c("{.field {name}} has no layer for survey year{?s} {missing}
                         with {.code match = \"{match}\"}.",
                        "i" = "Layers cover {first} to {last}; {.code match =
                               \"nearest\"} takes the closest."))
    }
    tibble::tibble(survey_year = as.integer(survey_years),
                   layer_year = as.integer(chosen))
}

#' The values of a yearly layer for each location and survey year, with the
#' year used, the density and the log where asked
#' @noRd
yearly_layer_values <- function(layer, name, kind, served, match, density, log,
                                points, key, buffer, boundaries) {
    column <- paste0(name, buffer_suffix(buffer))
    entries <- list()
    entries[[column]] <- control_entry(name, kind, buffer, period = match)
    needed <- unique(stats::na.omit(served$layer_year))
    if (length(needed) == 0) {
        # no survey year has its layer: missing values, after the warning
        units <- if (!is.null(boundaries)) terra::values(boundaries)$ID_adm_div else
            terra::values(points)[[key]]
        values <- tidyr::expand_grid(..key = unique(as.character(units)),
                                     survey_year = served$survey_year)
        values[[column]] <- NA_real_
        values[[paste0(name, "_year")]] <- NA_integer_
        return(list(values = values, entries = entries))
    }
    picked <- layer[[base::match(needed, layer_years_of(layer))]]
    terra::time(picked) <- as.Date(paste0(needed, "-01-01"))
    one <- suppressMessages(control_values(picked, name, kind, points, key, buffer,
                                           boundaries))
    long <- tidyr::pivot_longer(one, -"..key", names_to = "layer_date",
                                values_to = "value")
    long$layer_year <- as.integer(substr(long$layer_date, 1, 4))
    long <- dplyr::inner_join(long, served, by = "layer_year",
                              relationship = "many-to-many")

    values <- tibble::tibble(..key = long$..key, survey_year = long$survey_year)
    values[[column]] <- long$value
    values[[paste0(name, "_year")]] <- long$layer_year

    if (isTRUE(density) && kind == "count") {
        area <- terra::cellSize(picked[[1]], unit = "km")
        names(area) <- "area"
        area <- suppressMessages(control_values(area, "area", "count", points, key,
                                                buffer, boundaries))
        names(area) <- c("..key", "..area")
        values <- dplyr::left_join(values, area, by = "..key")
        density_col <- paste0(name, "_density", buffer_suffix(buffer))
        values[[density_col]] <- values[[column]] / values$..area
        values$..area <- NULL
        entries[[density_col]] <- control_entry(name, kind, buffer, period = match,
                                                stat = "density", unit = "per km2")
    }
    if (name %in% log) {
        log_col <- paste0("log_", column)
        values[[log_col]] <- log1p(values[[column]])
        entries[[log_col]] <- control_entry(name, kind, buffer, period = match,
                                            stat = "log1p")
    }
    list(values = values, entries = entries)
}

#' Normals of a climate series over the years before each survey year
#' @noRd
climate_normals <- function(x, name, survey_years, years, fns, points, key,
                            boundaries) {
    raster <- suppressMessages(read_climate(x, variable = name))
    dates <- layer_dates(raster)
    values <- list()
    entries <- list()
    for (survey_year in survey_years) {
        from <- as.Date(paste0(survey_year - years, "-01-01"))
        to <- as.Date(paste0(survey_year - 1, "-12-31"))
        inside <- dates >= from & dates <= to
        if (!any(inside)) {
            cli::cli_abort("{.field {name}} has no data in the {years} years before
                            {survey_year}.")
        }
        covered <- range(as.integer(format(dates[inside], "%Y")))
        if (covered[1] > survey_year - years) {
            c4e_inform("{.field {name}} covers {covered[1]} to {covered[2]} of the
                        {years} years before {survey_year}.")
        }
        window <- select_by_dates(raster, from = from, to = to)
        extracted <- suppressMessages(if (!is.null(boundaries)) {
            extract_by_poly(window, boundaries)
        } else {
            extract_by_coord(window, points)
        })
        par <- suppressMessages(calc_par(extracted, fn = fns, prefix = name))
        par_meta <- c4e_meta(par)
        data <- tibble::as_tibble(par)
        stat_cols <- intersect(names(par_meta$indicators), names(data))
        part <- data[c(par_meta$key, stat_cols)]
        names(part)[1] <- "..key"
        part$..key <- as.character(part$..key)
        part$survey_year <- as.integer(survey_year)
        values[[length(values) + 1]] <- part
        for (col in stat_cols) {
            entry <- par_meta$indicators[[col]]
            entry$years <- years
            entries[[col]] <- entry
        }
    }
    list(values = dplyr::bind_rows(values), entries = entries)
}

normal_function <- function(stat) {
    switch(stat,
           mean   = \(v) mean(v, na.rm = TRUE),
           sd     = \(v) stats::sd(v, na.rm = TRUE),
           cv     = \(v) cv(v),
           min    = \(v) min(v, na.rm = TRUE),
           max    = \(v) max(v, na.rm = TRUE),
           median = \(v) stats::median(v, na.rm = TRUE),
           sum    = \(v) sum(v, na.rm = TRUE),
           cli::cli_abort("Unknown statistic {.val {stat}}; use mean, sd, cv, min,
                           max, median or sum."))
}
