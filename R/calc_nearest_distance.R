#' Calculate nearest distance between two SpatVector objects
#'
#' Computes the minimum distance from each feature in `x` to the nearest
#' feature in `y` using [terra::nearest()]. Returns `x` with an added
#' column containing the nearest distance in kilometers.
#'
#' If CRS differ, `y` is automatically reprojected to the CRS of `x`.
#'
#' @param x A `terra::SpatVector` (polygons, points, or lines).
#' @param y A `terra::SpatVector` containing target features.
#' @param ... Additional arguments passed to `terra::nearest()`
#'   (e.g., `method`, `centroids`, `distance`).
#' @param return_geometry Logical. If TRUE, returns a `SpatVector` with geometries.
#'   If FALSE (default), returns a tibble with polygon attributes only.
#'
#' @return Either a [terra::SpatVector] or a [tibble::tbl_df] equal to `x` with an added column:
#'   - `dist_nearest_km`: minimum distance to `y` in kilometers.
#'
#' @details
#' - Distance is 0 if features intersect.
#' - If CRS is geographic (lon/lat), consider using `method = "haversine"`.
#' - For projected CRS (meters), default Euclidean distance is used.
#'
#' @seealso [terra::nearest] [calc_distance]
#'
#' @examples
#' adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' points <- terra::vect(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' # distance from each household to the nearest division border
#' calc_nearest_distance(points, terra::as.lines(adm_div))
#'
#' @export

calc_nearest_distance <- function(x, y, return_geometry = FALSE, ...) {
    # CRS check
    if (!terra::same.crs(x, y)) {
        message("CRS do not match. Reprojecting y to x CRS.")
        y <- terra::project(y, terra::crs(x))
    }

    # compute nearest distance
    nearest_res <- terra::nearest(x, y, pairs = FALSE, ...)

    # add distance column (km)
    out <- x
    out$dist_nearest_km <- nearest_res$distance / 1000

    # return as tibble or SpatVector
    if (!return_geometry) {
        out <- out |>
            terra::values() |>
            dplyr::as_tibble()
    }

    return(out)
}
