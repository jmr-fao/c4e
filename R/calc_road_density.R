#' Compute Road Network Density per Polygon
#'
#' Computes road network density (length per unit area) for each polygon
#' by intersecting a line road network with polygon geometries.
#'
#' @param polygons A `terra::SpatVector` polygon object.
#' @param roads A `terra::SpatVector` line object representing roads.
#' @param poly_id Optional character string specifying the polygon ID column.
#'   If NULL, the function searches for `"ID"` or `"ID_adm_div"`.
#' @param return_geometry Logical. If TRUE, returns a `SpatVector` with geometries.
#'   If FALSE (default), returns a tibble with polygon attributes only.
#'
#' @return Either a [terra::SpatVector] or a [tibble::tbl_df] with columns:
#'   \describe{
#'     \item{road_length_km}{Total road length inside each polygon in km}
#'     \item{n_roads}{Number of road segments intersecting each polygon}
#'     \item{area_km2}{Polygon area in km²}
#'     \item{road_density}{Road length per km²}
#'   }
#'
#' @seealso [terra::intersect] [terra::perim]
#'
#' @export
#'
#' @examples
#' adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
#' roads <- terra::vect(c("LINESTRING (30 -0.5, 31.2 -0.5)",
#'                        "LINESTRING (30.6 -1, 30.6 0.2)"), crs = "EPSG:4326")
#'
#' # a tibble (default)
#' calc_road_density(adm_div, roads)
#'
#' # a SpatVector with the geometries
#' calc_road_density(adm_div, roads, return_geometry = TRUE)

calc_road_density <- function(polygons, roads, poly_id = NULL, return_geometry = FALSE) {

    # check CRS
    if (!terra::same.crs(polygons, roads)) {
        warning("CRS of polygons and roads do not match. Roads are reprojected to match polygons")
        roads <- terra::project(roads, terra::crs(polygons))
    }

    poly_id <- resolve_key(polygons, poly_id, arg = "poly_id")

    # intersect roads with polygons
    roads_split <- vect_select(terra::intersect(roads, polygons), poly_id)
    area_km2 <- terra::expanse(polygons, unit = "km")

    # if there are no intersection return 0
    if (nrow(roads_split) == 0) {
        warning("No intersections found.")
        polygons$road_length_km <- 0
        polygons$n_roads <- 0
        polygons$area_km2 <- area_km2
        polygons$road_density <- 0

        if (!return_geometry) return(dplyr::as_tibble(polygons))
        return(polygons)
    }

    # compute road length
    roads_split$road_length_km <- terra::perim(roads_split) / 1000

    # aggregate by polygon ID
    road_sum <- roads_split |>
        terra::aggregate(by = poly_id, fun = sum, na.rm = TRUE, count = TRUE) |>
        terra::values()
    names(road_sum)[names(road_sum) == "agg_road_length_km"] <- "road_length_km"
    names(road_sum)[names(road_sum) == "agg_n"] <- "n_roads"

    # merge back to polygons, in their own order
    matched <- match(terra::values(polygons)[[poly_id]], road_sum[[poly_id]])
    road_length_km <- road_sum$road_length_km[matched]
    n_roads <- road_sum$n_roads[matched]
    polygons$road_length_km <- ifelse(is.na(road_length_km), 0, road_length_km)
    polygons$n_roads <- ifelse(is.na(n_roads), 0, n_roads)
    polygons$area_km2 <- area_km2
    polygons$road_density <- polygons$road_length_km / area_km2

    # return as tibble or SpatVector
    if (!return_geometry) polygons <- dplyr::as_tibble(polygons)
    polygons
}
