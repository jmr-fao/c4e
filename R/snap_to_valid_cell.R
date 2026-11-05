# Points that fall in an empty cell (plan 7.4).
#
# Land-only grids stop at the coast, and a coastline the grid cannot resolve
# leaves a household standing on real land in a cell with no value. Moving
# the point to the nearest cell that has one reads the same number as filling
# the raster and extracting afterwards, at a fraction of the cost when the
# raster is a long daily stack rather than one layer.

#' Move points off the empty cells of a grid
#'
#' Finds the locations that fall in a cell with no value and moves each to
#' the centre of the nearest cell that has one, within `radius_deg`, leaving
#' every other location untouched. Intended for land-only grids — ERA5-Land
#' is a land model on a 0.1 degree grid, GloFAS stops at the coast — where a
#' household on land can sit in an empty cell.
#'
#' Nearest rather than interpolated, and bounded, so a moved point reads one
#' real neighbouring cell's value and cannot take one from across the
#' country. A location further than `radius_deg` from any cell with a value
#' is left where it is, and reads `NA`: the usual reason is that it is
#' genuinely offshore.
#'
#' [fill_missing_rast()] does the same job on the raster, by a focal mean
#' over the neighbours rather than by taking one of them. Prefer that when
#' the raster is the thing to keep, and this when the points are: filling a
#' forty-year daily stack to change the value of a handful of locations
#' interpolates some fifteen thousand layers to no purpose.
#'
#' @param x A data frame with coordinate columns, or a table from
#'   [prepare_coord()].
#' @param raster A `SpatRaster`, or a file path. Only `layer` is looked at:
#'   the cells a land mask leaves empty are the same on every date.
#' @param radius_deg How far a point may be moved, in degrees, converted at
#'   111 320 m per degree. The default 0.25 is two and a half cells of the
#'   0.1 degree ERA5-Land grid.
#' @param lat,lon <[`tidy-select`][dplyr::dplyr_tidy_select]> Coordinate
#'   columns; `lat` and `lon` by default.
#' @param layer Which layer to read the empty cells from.
#'
#' @return `x` with the coordinates of the moved points replaced, and a
#'   `snapped` column: `TRUE` where the point was moved, `FALSE` where it
#'   was already in a cell with a value or no cell was near enough. The
#'   original coordinates are kept in `lat_given` and `lon_given`.
#'
#' @seealso [fill_missing_rast()], [extract_by_coord()]
#' @export
#'
#' @examples
#' \dontrun{
#' pre <- read_climate(files, variable = "pre")
#' places |>
#'     snap_to_valid_cell(pre) |>
#'     prepare_coord(lat, lon, id = place)
#' }
snap_to_valid_cell <- function(x, raster, radius_deg = 0.25, lat = lat,
                               lon = lon, layer = 1) {
    started <- Sys.time()
    lat_name <- rlang::as_name(rlang::enquo(lat))
    lon_name <- rlang::as_name(rlang::enquo(lon))
    data <- tibble::as_tibble(x)
    absent <- setdiff(c(lat_name, lon_name), names(data))
    if (length(absent)) {
        cli::cli_abort("{.arg x} has no {.field {absent}} column{?s}.")
    }
    if (!is.numeric(radius_deg) || length(radius_deg) != 1 || radius_deg <= 0) {
        cli::cli_abort("{.arg radius_deg} must be one positive number.")
    }
    if (!inherits(raster, "SpatRaster")) {
        raster <- terra::rast(raster)
    }

    data$lat_given <- data[[lat_name]]
    data$lon_given <- data[[lon_name]]
    data$snapped <- FALSE

    ok <- !is.na(data[[lat_name]]) & !is.na(data[[lon_name]])
    if (!any(ok)) {
        c4e_inform("No location has coordinates; nothing to move.")
        return(restore_class(x, data))
    }

    one <- raster[[layer]]
    points <- terra::vect(as.data.frame(data[ok, c(lon_name, lat_name)]),
                          geom = c(lon_name, lat_name), crs = "EPSG:4326")
    empty <- is.na(terra::extract(one, points, ID = FALSE)[[1]])
    if (!any(empty)) {
        c4e_inform("Every location has a cell of its own.")
        return(restore_class(x, data))
    }

    cells <- terra::as.points(one, values = TRUE, na.rm = TRUE)
    if (length(cells) == 0) {
        cli::cli_abort("{.arg raster} has no cell with a value to move to.")
    }
    near <- terra::nearest(points[empty], cells)
    moved <- tibble::as_tibble(as.data.frame(near))
    within <- !is.na(moved$distance) & moved$distance <= radius_deg * 111320

    rows <- which(ok)[empty]
    data[[lon_name]][rows[within]] <- moved$to_x[within]
    data[[lat_name]][rows[within]] <- moved$to_y[within]
    data$snapped[rows[within]] <- TRUE

    n_empty <- sum(empty)
    n_moved <- sum(within)
    c4e_inform("{n_empty} location{?s} {?has/have} no cell of {?its/their} own;
                {n_moved} moved to the nearest cell within {radius_deg}
                degree{?s}.")
    if (n_moved < n_empty) {
        n_left <- n_empty - n_moved
        c4e_inform("{n_left} {?is/are} further than that from any cell with a
                    value and {?is/are} left where {?it/they} {?is/are}.")
    }
    restore_class(x, data)
}

#' Give the result the class the input had
#' @noRd
restore_class <- function(x, data) {
    meta <- c4e_meta(x)
    if (is.null(meta)) {
        return(data)
    }
    new_c4e_tbl(data, prune_meta(meta, names(data)))
}
