#' Extract Raster Values by Polygon
#'
#' This function extracts the values of every raster cell within each
#' polygon, with the fraction of the cell inside the polygon, using the
#' `exactextractr` package on the `terra` raster directly.
#'
#' Each cell is identified by the polygon it belongs to and its centre. The
#' polygon identifier is the polygon's own `ID_adm_div` (or the column named
#' by `id`) when it has one, else its row number. The result is a `c4e_tbl`
#' carrying the raster's context, ready for cell-level indicators that are
#' later aggregated with the coverage fractions.
#'
#' When the result would exceed the memory budget (see
#' `?c4e`), the layers are extracted in blocks and bound
#' together.
#'
#' @param raster A `SpatRaster` representing the raster data to extract.
#' @param poly A `SpatVector` or `sf` object representing the polygon(s) for
#'   extraction.
#' @param id Optional name of the column of `poly` identifying the polygons.
#'   The result's identifier column takes this name. Default `ID_adm_div`.
#' @param label Optional name shown in progress messages.
#' @param chunk `"auto"` extracts in blocks of layers only when needed; a
#'   whole number forces that many layers per block; `FALSE` never splits.
#' @param ... additional arguments to pass to [exactextractr::exact_extract].
#'
#' @return A `c4e_tbl` with the polygon identifier, the cell coordinates
#'   (`x_cell`, `y_cell`), the `coverage_fraction` and one column per layer.
#'
#' @seealso \code{\link[exactextractr]{exact_extract}}, [extract_by_poly()]
#'
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' adm_div <- terra::vect(
#'   system.file("extdata", "adm_div.gpkg", package = "c4e"))
#'
#' # one row per cell and division, with the share of the cell inside it
#' extract_cell_by_poly(tmax[[1:3]], adm_div)
extract_cell_by_poly <- function(raster, poly, id = NULL, label = NULL,
                                 chunk = "auto", ...) {
    started <- Sys.time()
    poly <- as_spat_vector(poly)
    check_same_crs(raster, poly, arg = "poly")
    if (!is.null(label)) {
        c4e_progress_step("Extracting {label}")
    }

    key <- id %||% "ID_adm_div"
    poly_ids <- if (key %in% names(poly)) {
        as.character(terra::values(poly)[[key]])
    } else {
        as.character(seq_len(nrow(poly)))
    }
    poly_sf <- sf::st_as_sf(poly)

    extract_fn <- function(layers, first) {
        cells <- exactextractr::exact_extract(layers, poly_sf,
                                              include_xy = TRUE,
                                              force_df = TRUE,
                                              progress = FALSE, ...)
        names(cells) <- poly_ids
        cells <- dplyr::bind_rows(cells, .id = key) |>
            tibble::as_tibble() |>
            dplyr::rename_with(~gsub("\\.", "_", .x))
        if (terra::nlyr(layers) == 1 && "value" %in% names(cells)) {
            names(cells)[names(cells) == "value"] <- gsub("\\.", "_", names(layers))
        }
        if (!first) {
            return(dplyr::select(cells, -dplyr::any_of(c(key, "x", "y",
                                                         "coverage_fraction"))))
        }
        cells |>
            dplyr::relocate(dplyr::all_of(c(key, "x", "y", "coverage_fraction"))) |>
            dplyr::rename(x_cell = "x", y_cell = "y")
    }
    n_cells <- terra::ncell(terra::crop(raster[[1]], poly, snap = "out"))
    out <- extract_in_blocks(raster, n_cells, extract_fn, chunk = chunk,
                             label = "Cell extraction")

    meta <- extraction_meta(raster, out, key,
                            c("x_cell", "y_cell", "coverage_fraction"),
                            spatial_agg = list(level = "cell"),
                            fn_name = "extract_cell_by_poly",
                            args = list(id = id),
                            started = started)
    new_c4e_tbl(out, meta)
}
