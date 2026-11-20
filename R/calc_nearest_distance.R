#' Calculate nearest distance between two SpatVector objects
#'
#' Computes the minimum distance from each feature in `x` to the nearest
#' feature in `y`. Returns `x` with an added column containing the nearest
#' distance in kilometers.
#'
#' When the sf package is installed and no arguments are passed in `...`,
#' the nearest feature is found with [sf::st_nearest_feature()], which uses a
#' spatial index, and the distance to it is measured with
#' [terra::distance()]. This is much faster on many features and exact: on
#' longitude and latitude, 500 points to 7,700 road lines take under a
#' second instead of minutes, and [terra::nearest()] can be tens of
#' per cent off on lines there. Otherwise [terra::nearest()] is used.
#'
#' If CRS differ, `y` is automatically reprojected to the CRS of `x`.
#'
#' @param x A `terra::SpatVector` (polygons, points, or lines).
#' @param y A `terra::SpatVector` containing target features.
#' @param ... Additional arguments passed to `terra::nearest()`
#'   (e.g., `method`, `centroids`, `distance`); giving any uses
#'   [terra::nearest()] rather than sf.
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

    # compute nearest distance: sf finds the nearest feature through a
    # spatial index, terra::nearest() measures to every feature (minutes for
    # hundreds of points and thousands of lines in lon/lat)
    distance <- if (...length() == 0 && rlang::is_installed("sf")) {
        nearest_distance_sf(x, y)
    } else {
        terra::nearest(x, y, pairs = FALSE, ...)$distance
    }

    # add distance column (km)
    out <- x
    out$dist_nearest_km <- distance / 1000

    # return as tibble or SpatVector
    if (!return_geometry) {
        out <- out |>
            terra::values() |>
            dplyr::as_tibble()
    }

    return(out)
}

## Distance in metres from each feature of x to the nearest feature of y:
## sf finds which feature is nearest, terra measures the distance to it (on
## the ellipsoid in lon/lat, where sf measures on a sphere)
nearest_distance_sf <- function(x, y) {
    nearest <- sf::st_nearest_feature(sf::st_as_sf(x), sf::st_as_sf(y))
    terra::distance(x, y[nearest], pairwise = TRUE)
}
