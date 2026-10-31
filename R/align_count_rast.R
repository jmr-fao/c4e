#' Align a Count Raster onto the Grid of Another Raster
#'
#' Resamples a raster of counts (people, livestock heads) onto the grid of
#' `template` so that it can serve as extraction weights for `template`, for
#' example with [extract_weighted_by_poly()].
#'
#' @details
#' A count cannot be interpolated like a continuous value. The method follows
#' the resolutions:
#' * `template` coarser than `count`: the counts are summed into each template
#'   cell, so totals are preserved. When the grids nest (the resolution ratio
#'   is a whole number and the cell edges line up, e.g. 30 arc-seconds into
#'   5 arc-minutes) the sum is exact, with [terra::aggregate()]; otherwise
#'   each count is shared by the area of the count cell inside each template
#'   cell. (Not [terra::resample()] with `method = "sum"`, whose result
#'   depends on the GDAL version.)
#' * `template` as fine as or finer than `count`: each template cell takes the
#'   count of the cell it falls in (`method = "near"`). Totals are not
#'   preserved, but the relative weights between cells are, which is what a
#'   weighting needs.
#'
#' `NA` counts are set to 0. Weights must have no `NA`, because
#' [exactextractr::exact_extract()] returns `NaN` for a polygon when any of its
#' weight cells is `NA`.
#'
#' @param count A `SpatRaster` of counts, in the same CRS as `template`.
#' @param template A `SpatRaster` whose grid the counts are put on.
#' @param tolerance Relative margin below which the two resolutions are
#'   treated as equal. Default `0.01`.
#' @param iteration optional character to be print before computation. Usually,
#'  it is the name of the object on which the function is applied. This is useful
#'  when the function is used inside an apply family function to keep track of the
#'  iterations.
#'
#' @return A `SpatRaster` on the grid of `template`, with no `NA`.
#'
#' @seealso [extract_weighted_by_poly()], [terra::resample()]
#' @export
#'
#' @examples
#' pop <- terra::rast(xmin = 0, xmax = 1, ymin = 0, ymax = 1, res = 0.1,
#'                    crs = "epsg:4326", vals = 1)
#' coarse <- terra::rast(xmin = 0, xmax = 1, ymin = 0, ymax = 1, res = 0.5,
#'                       crs = "epsg:4326", vals = 0)
#' align_count_rast(pop, coarse) # 25 people in each coarse cell
align_count_rast <- function(count, template, tolerance = 0.01,
                             iteration = NULL) {
    if (!is.null(iteration)) cat("Aligning:", iteration, "\n")

    checkmate::assert_class(count, "SpatRaster")
    checkmate::assert_class(template, "SpatRaster")
    checkmate::assert_number(tolerance, lower = 0)

    coarser <- terra::res(template)[1] > terra::res(count)[1] * (1 + tolerance)

    if (!coarser) {
        aligned <- terra::resample(count, template, method = "near")
    } else if (is_nested(count, template, tolerance)) {
        ## cut to the template's extent first, so that the blocks summed start
        ## at the template's corner
        fact <- round(terra::res(template) / terra::res(count))
        aligned <- count |>
            terra::extend(terra::ext(template), snap = "near") |>
            terra::crop(terra::ext(template), snap = "near") |>
            terra::aggregate(fact = fact, fun = "sum", na.rm = TRUE) |>
            terra::resample(template, method = "near")
    } else {
        aligned <- overlap_sum(count, template)
    }

    terra::classify(aligned, cbind(NA, 0))
}

## Sum the counts into the template cells, each count cell shared by the area
## it has in each template cell. Both grids are regular and north-up, so the
## share is the column overlap times the row overlap. Not
## terra::resample(method = "sum"): GDAL's sum differs between versions.
overlap_sum <- function(count, template) {
    empty <- terra::rast(template, nlyrs = terra::nlyr(count), names = names(count),
                         vals = 0)
    if (is.null(terra::intersect(terra::ext(count), terra::ext(template)))) {
        return(empty)
    }
    count <- terra::crop(count, terra::ext(template), snap = "out")
    nr <- terra::nrow(count)
    nc <- terra::ncol(count)
    cols <- overlap_pairs(terra::xmin(count), terra::res(count)[1], nc,
                          terra::xmin(template), terra::res(template)[1],
                          terra::ncol(template))
    rows <- overlap_pairs(-terra::ymax(count), terra::res(count)[2], nr,
                          -terra::ymax(template), terra::res(template)[2],
                          terra::nrow(template))

    sums <- lapply(seq_len(terra::nlyr(count)), \(layer) {
        values <- matrix(terra::values(count[[layer]], mat = FALSE), nr, nc,
                         byrow = TRUE)
        values[is.na(values)] <- 0
        by_col <- matrix(0, terra::ncol(template), nr) # template columns x count rows
        summed <- rowsum(t(values)[cols$from, , drop = FALSE] * cols$share, cols$to)
        by_col[as.integer(rownames(summed)), ] <- summed
        out <- matrix(0, terra::nrow(template), terra::ncol(template))
        summed <- rowsum(t(by_col)[rows$from, , drop = FALSE] * rows$share, rows$to)
        out[as.integer(rownames(summed)), ] <- summed
        as.vector(t(out))
    })
    terra::values(empty) <- do.call(cbind, sums)
    empty
}

## Along one axis: which cells of the second grid each cell of the first
## overlaps, and the share of the first cell's width inside it
overlap_pairs <- function(from_start, from_res, n_from, to_start, to_res, n_to) {
    from_lo <- from_start + (seq_len(n_from) - 1) * from_res
    from_hi <- from_lo + from_res
    first <- floor((from_lo - to_start) / to_res) + 1
    span <- ceiling(from_res / to_res) + 1
    pairs <- lapply(0:span, \(step) {
        to <- first + step
        to_lo <- to_start + (to - 1) * to_res
        width <- pmin(from_hi, to_lo + to_res) - pmax(from_lo, to_lo)
        data.frame(from = seq_len(n_from), to = to, share = width / from_res)
    })
    pairs <- do.call(rbind, pairs)
    pairs[pairs$share > 1e-12 & pairs$to >= 1 & pairs$to <= n_to, , drop = FALSE]
}

## TRUE when every cell of `template` is made of whole cells of `count`: a
## whole-number resolution ratio and cell edges that line up
is_nested <- function(count, template, tolerance) {
    ratio <- terra::res(template) / terra::res(count)
    whole_ratio <- all(abs(ratio - round(ratio)) < tolerance)

    ## distance of the template's corner from the count grid, in count cells
    offset <- (c(terra::xmin(template), terra::ymax(template)) -
                   c(terra::xmin(count), terra::ymax(count))) / terra::res(count)
    edges_align <- all(abs(offset - round(offset)) < tolerance)

    whole_ratio && edges_align
}
