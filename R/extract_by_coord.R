#' Extract values from a SpatRaster
#'
#' Extract values from a \link[terra]{SpatRaster} for a set of locations.
#' The locations must be a point \link[terra]{SpatVector}.
#'
#' The result is a `c4e_tbl` that carries the raster's context: variable,
#' unit, time step, dates, CRS and data source, as recorded by
#' [read_climate()]. Later steps read their defaults from it.
#'
#' The raster and the locations must share a CRS. Locations outside the
#' raster, or on cells that are missing in every layer, are reported with
#' their identifiers.
#'
#' With `buffer`, each location gets a summary of the cells within that
#' distance instead of the value of its own cell: the mean for continuous
#' variables, the sum for counts (population) and the most frequent value
#' for categories, unless `fn` says otherwise.
#'
#' When the result would exceed the memory budget (see
#' `?climatic4economist`), the layers are extracted in blocks and bound
#' together, with a progress bar.
#'
#' @param raster A \link[terra]{SpatRaster}. Each layer becomes one column of
#'   the result.
#' @param coord A point \link[terra]{SpatVector} carrying the unit identifier,
#'   typically created with [georef_coord()].
#' @param id Optional character string naming the column that identifies the
#'   units. When `NULL`, `ID` is used, or `ID_adm_div` when that is the only
#'   one present.
#' @param iteration Deprecated; use `label`.
#' @param buffer Optional distance in metres around each location to
#'   summarise.
#' @param fn Summary over a buffer: `"mean"`, `"sum"`, `"mode"`, `"min"`,
#'   `"max"` or a function. Defaults from the kind of variable.
#' @param label Optional name shown in progress messages.
#' @param chunk `"auto"` extracts in blocks of layers only when needed; a
#'   whole number forces that many layers per block; `FALSE` never splits.
#' @param ... additional arguments to pass to [terra::extract].
#'
#' @returns A `c4e_tbl` with the extracted values for each location and the
#'   coordinates of its cell (`x_cell`, `y_cell`). If the raster has multiple
#'   layers, the values of the layer will be split by columns.
#'
#' @seealso \code{\link[terra]{extract}}, [extract_by_poly()],
#'   [extract_cell_by_poly()]
#'
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "climatic4economist"))
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "climatic4economist"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' extract_by_coord(tmax[[1:5]], points)
#'
#' # the mean of the cells within 20 km of each location
#' extract_by_coord(tmax[[1:5]], points, buffer = 20000)
extract_by_coord <- function(raster, coord, iteration = NULL, id = NULL,
                             buffer = NULL, fn = NULL, label = NULL,
                             chunk = "auto", ...) {
    started <- Sys.time()
    coord <- as_spat_vector(coord)
    check_same_crs(raster, coord)
    label <- resolve_label(label, iteration)
    if (!is.null(label)) {
        c4e_progress_step("Extracting {label}")
    }

    if (!is.null(buffer)) {
        return(extract_buffer(raster, coord, id, buffer, fn, started, ...))
    }

    extract_fn <- function(layers, first) {
        if (!first) {
            values <- terra::extract(layers, coord, ID = FALSE, ...)
            return(name_value_columns(tibble::as_tibble(values), layers))
        }
        out <- terra::extract(layers, coord, ID = FALSE, ...) |>
            tibble::as_tibble() |>
            name_value_columns(layers)
        cells <- terra::xyFromCell(layers, terra::cellFromXY(layers, terra::crds(coord)))
        out <- dplyr::bind_cols(
            tibble::as_tibble(terra::values(coord)) |>
                dplyr::rename_with(~gsub("\\.", "_", .x)),
            tibble::tibble(x = cells[, 1], y = cells[, 2]),
            out
        )
        key <- resolve_key(out, id)
        out |>
            dplyr::relocate(dplyr::all_of(c(key, "x", "y"))) |>
            dplyr::rename(x_cell = "x", y_cell = "y")
    }
    out <- extract_in_blocks(raster, nrow(coord), extract_fn, chunk = chunk,
                             label = "Point extraction")

    key <- resolve_key(out, id)
    report_missing_points(coord, raster,
                          out[intersect(layer_columns(raster), names(out))],
                          out[[key]])

    meta <- extraction_meta(raster, out, key, c("x_cell", "y_cell"),
                            spatial_agg = list(level = "point"),
                            fn_name = "extract_by_coord",
                            args = list(id = id, chunk = if (!identical(chunk, "auto")) chunk),
                            started = started)
    new_c4e_tbl(out, meta)
}

#' Summaries of the cells within a distance of each location
#' @noRd
extract_buffer <- function(raster, coord, id, buffer, fn, started, ...) {
    if (!is.numeric(buffer) || length(buffer) != 1 || !isTRUE(buffer > 0)) {
        cli::cli_abort("{.arg buffer} must be a positive distance in metres.",
                       call = rlang::caller_env())
    }
    fn <- fn %||% default_space_fn(raster_meta(raster))$fn
    zones <- terra::buffer(coord, width = buffer)
    values <- terra::extract(raster, zones, fun = terra_summary(fn), na.rm = TRUE,
                             ID = FALSE, ...) |>
        tibble::as_tibble() |>
        name_value_columns(raster)
    out <- dplyr::bind_cols(tibble::as_tibble(terra::values(coord)), values)
    key <- resolve_key(out, id)
    out <- dplyr::relocate(out, dplyr::all_of(key))

    fn_name <- if (is.character(fn)) fn else "custom"
    meta <- extraction_meta(raster, out, key, NULL,
                            spatial_agg = list(level = "buffer", fn = fn_name,
                                               buffer = buffer),
                            fn_name = "extract_by_coord",
                            args = list(id = id, buffer = buffer, fn = fn_name),
                            started = started)
    new_c4e_tbl(out, meta)
}
