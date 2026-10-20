#' Extract and Aggregate Raster Values by Polygons
#'
#' This function extracts raster values within polygon features and aggregates them
#' using a specified summary function (e.g., "mean", "sum", "mode"). It returns
#' the extracted values as a `c4e_tbl` carrying the raster's context.
#'
#' @details
#' With `pkg = "terra"`, cells whose centre lies in a polygon count fully.
#' With `pkg = "exactextractr"`, or `weights = "coverage"`, each cell counts
#' by the fraction of it inside the polygon, which matters for small
#' polygons and coarse rasters; the computation runs in C++. For other
#' weights, such as population, see [extract_weighted_by_poly()].
#'
#' When `fn_agg` is not given it follows from the kind of variable recorded
#' by [read_climate()]: the mean for continuous variables, the sum for
#' counts (population) and the most frequent value for categories. The
#' choice is announced.
#'
#' The raster and the polygons must share a CRS.
#'
#' @param raster A \code{SpatRaster} object from the \code{terra} package.
#' @param poly A \code{SpatVector} or \code{sf} object representing polygon features.
#' @param fn_agg A function or character string specifying how to aggregate
#'   raster values within each polygon, e.g. `"mean"`, `"sum"`, `"mode"`.
#'   Defaults from the kind of variable, else `"mean"`.
#' @param na_rm Logical. If \code{TRUE}, \code{NA} values in the raster are
#'   ignored during aggregation. Default is \code{TRUE}.
#' @param pkg Optional character string. The package to use: \code{"terra"} or
#'   \code{"exactextractr"}. If \code{NULL}, a package is chosen based on polygon count.
#'   Default is \code{"terra"}.
#' @param id Optional name of the column of `poly` identifying the polygons.
#'   When `NULL`, `ID` or `ID_adm_div` is used when present.
#' @param weights `NULL`, or `"coverage"` to weight each cell by the fraction
#'   of it inside the polygon (uses `exactextractr`).
#' @param label Optional name shown in progress messages.
#'
#' @return A `c4e_tbl` with the attributes of `poly` and the aggregated raster
#'   values, one row per polygon.
#'
#' @seealso \code{\link[terra]{extract}}, \code{\link[exactextractr]{exact_extract}},
#'   [extract_weighted_by_poly()], [extract_cell_by_poly()]
#'
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' adm_div <- terra::vect(
#'   system.file("extdata", "adm_div.gpkg", package = "c4e"))
#'
#' extract_by_poly(tmax[[1:5]], adm_div)
#' extract_by_poly(tmax[[1:5]], adm_div, weights = "coverage")
extract_by_poly <- function(raster, poly, fn_agg = NULL, na_rm = TRUE,
                            pkg = "terra", id = NULL, weights = NULL,
                            label = NULL) {
    started <- Sys.time()
    poly <- as_spat_vector(poly)
    check_same_crs(raster, poly, arg = "poly")
    if (!is.null(label)) {
        c4e_progress_step("Extracting {label}")
    }

    if (is.null(fn_agg)) {
        choice <- default_space_fn(raster_meta(raster))
        fn_agg <- choice$fn
        if (!is.null(choice$reason)) {
            reason <- choice$reason
            c4e_inform("Summarising by polygon with {.code fn_agg = \"{fn_agg}\"}:
                        {reason}.")
        }
    }
    if (!is.null(weights)) {
        if (!identical(weights, "coverage")) {
            cli::cli_abort(c(
                "{.arg weights} must be {.code NULL} or {.val coverage}.",
                "i" = "For population or other weights, use
                       {.fn extract_weighted_by_poly}."
            ))
        }
        pkg <- "exactextractr"
    }
    if (is.null(pkg)) {
        pkg <- if (nrow(poly) > 1000) "exactextractr" else "terra"
    }
    pkg <- match.arg(pkg, c("exactextractr", "terra"))

    if (pkg == "terra") {
        values <- terra::extract(raster, poly, fun = terra_summary(fn_agg),
                                 ID = FALSE, na.rm = na_rm) |>
            dplyr::as_tibble() |>
            name_value_columns(raster)
        out <- dplyr::bind_cols(dplyr::as_tibble(terra::values(poly)), values)
    } else {
        out <- exactextractr::exact_extract(raster, sf::st_as_sf(poly),
                                            fun = fn_agg,
                                            append_cols = names(poly),
                                            force_df = TRUE,
                                            progress = FALSE) |>
            dplyr::rename_with(\(x) gsub(paste0("^", fn_agg, "\\."), "", x)) |>
            dplyr::as_tibble()
        if (terra::nlyr(raster) == 1 && fn_agg %in% names(out)) {
            names(out)[names(out) == fn_agg] <- names(raster)
        }
    }

    key <- key_or_null(out, id)
    if (!is.null(key)) {
        out <- dplyr::relocate(out, dplyr::all_of(key))
    }
    fn_name <- if (is.character(fn_agg)) fn_agg else "custom"
    spatial_agg <- list(level = "poly", fn = fn_name)
    if (!is.null(weights)) {
        spatial_agg$weights <- weights
    }
    meta <- extraction_meta(raster, out, key, NULL, spatial_agg,
                            fn_name = "extract_by_poly",
                            args = list(fn_agg = fn_name, pkg = pkg, id = id,
                                        weights = weights),
                            started = started)
    restore_grid_table(new_c4e_tbl(out, meta), raster)
}
