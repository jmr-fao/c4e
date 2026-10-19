#' Weighted Mean or Mode of Raster Values by Polygon
#'
#' Summarises each layer of a raster over each polygon, with every cell
#' counting by the fraction of it inside the polygon times a weight: its area
#' by default, or a count such as population.
#'
#' @details
#' Each cell counts by \eqn{f_c w_c}, where \eqn{f_c} is the fraction of the
#' cell inside the polygon ([exactextractr::exact_extract()]) and \eqn{w_c} the
#' weight of the cell:
#' * `weights = NULL`: the cell area in km2. On a lon-lat grid cells shrink
#'   towards the poles, so area weights differ from a plain average of cells.
#' * `weights` a `SpatRaster`, e.g. population: the polygon value describes
#'   the conditions where people live rather than the territory. A weight
#'   raster on another grid is put on the grid of `raster` with
#'   [align_count_rast()], so it must hold counts.
#'
#' A polygon whose weights are all zero (no population) falls back to the
#' coverage fractions alone. Cells where `raster` is `NA` are ignored; a
#' polygon with no valid cell gets `NA`.
#'
#' `stat = "mean"` returns the weighted mean, for continuous layers.
#' `stat = "mode"` returns the class with the largest total weight, for class
#' layers (land cover, climate zones); ties go to the lowest class.
#'
#' @param raster A `SpatRaster`, one or more layers.
#' @param poly A `SpatVector` or `sf` object of polygons, in the CRS of
#'   `raster`.
#' @param stat `"mean"` (default) or `"mode"`.
#' @param weights `NULL` (default) for area weights, or a single-layer
#'   `SpatRaster` of weights.
#' @param iteration Deprecated; use `label`.
#' @param id Optional name of the column of `poly` identifying the polygons.
#'   When `NULL`, `ID` or `ID_adm_div` is used when present.
#' @param label Optional name shown in progress messages.
#'
#' @return A `c4e_tbl` carrying the raster's context, with one row per
#'   polygon: the attributes of `poly`, then
#'   one column per layer of `raster`, named after it.
#'
#' @seealso [extract_by_poly()] for unweighted statistics,
#'   [align_count_rast()], [exactextractr::exact_extract()]
#' @export
#'
#' @examples
#' r <- terra::rast(xmin = 0, xmax = 2, ymin = 0, ymax = 1, res = 1,
#'                  crs = "epsg:4326", vals = c(10, 20))
#' names(r) <- "value"
#' pop <- terra::rast(r, vals = c(1, 3))
#' p <- terra::vect(terra::ext(0, 2, 0, 1), crs = "epsg:4326")
#' p$id <- 1
#'
#' extract_weighted_by_poly(r, p)                 # area: about 15
#' extract_weighted_by_poly(r, p, weights = pop)  # people: 17.5
extract_weighted_by_poly <- function(raster, poly, stat = c("mean", "mode"),
                                     weights = NULL, iteration = NULL,
                                     id = NULL, label = NULL) {
    started <- Sys.time()
    stat <- match.arg(stat)
    checkmate::assert_class(raster, "SpatRaster")
    checkmate::assert_multi_class(poly, c("SpatVector", "sf"))
    checkmate::assert_class(weights, "SpatRaster", null.ok = TRUE)
    check_same_crs(raster, as_spat_vector(poly), arg = "poly")
    label <- resolve_label(label, iteration)
    if (!is.null(label)) {
        c4e_progress_step("Extracting {label}")
    }
    weight_kind <- if (is.null(weights)) "area" else "raster"

    if (is.null(weights)) {
        weights <- terra::cellSize(raster[[1]], unit = "km")
    } else if (!terra::compareGeom(raster, weights, stopOnError = FALSE)) {
        weights <- align_count_rast(weights, raster)
    } else {
        weights <- terra::classify(weights, cbind(NA, 0))
    }

    poly_sf <- sf::st_as_sf(poly)

    values <- purrr::map(
        rlang::set_names(names(raster)),
        \(layer) summarise_weighted(raster[[layer]], poly_sf, weights, stat)
    )

    out <- dplyr::bind_cols(
        tibble::as_tibble(sf::st_drop_geometry(poly_sf)),
        tibble::as_tibble(values)
    )

    key <- key_or_null(out, id)
    meta <- extraction_meta(raster, out, key, NULL,
                            spatial_agg = list(level = "poly", fn = stat,
                                               weights = weight_kind),
                            fn_name = "extract_weighted_by_poly",
                            args = list(stat = stat, id = id),
                            started = started)
    new_c4e_tbl(out, meta)
}

## One layer, one statistic: a numeric vector, one value per polygon
summarise_weighted <- function(layer, poly_sf, weights, stat) {
    if (stat == "mean") {
        ext <- exactextractr::exact_extract(
            layer, poly_sf, c("weighted_mean", "mean"),
            weights = weights, force_df = TRUE, progress = FALSE
        )
        return(dplyr::coalesce(ext$weighted_mean, ext$mean))
    }

    exactextractr::exact_extract(
        layer, poly_sf,
        \(df) {
            df <- df[!is.na(df$value), ]
            if (nrow(df) == 0) return(NA_real_)
            w <- tapply(df$coverage_fraction * df$weight, df$value, sum)
            if (sum(w) == 0) {
                w <- tapply(df$coverage_fraction, df$value, sum)
            }
            as.numeric(names(w)[which.max(w)])
        },
        weights      = weights,
        summarize_df = TRUE,
        progress     = FALSE
    )
}
