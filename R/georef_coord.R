#' Georeference based on coordinates and coordinate reference system
#'
#' Turns the distinct locations of a survey into a point
#' \link[terra]{SpatVector}, one point per location ID, ready for
#' `extract_*()`.
#'
#' After [prepare_coord()], the coordinate columns are known and `geom` can be
#' left out. Without a `crs`, the coordinates are taken as longitude and
#' latitude on WGS 84 (`"EPSG:4326"`), which is announced.
#'
#' @param df A data frame, typically from [prepare_coord()].
#' @param geom character. The field names with the x and y coordinates of the
#'   points. Defaults to the columns recorded by [prepare_coord()].
#' @param crs character. The coordinate reference system in one of the following
#'   formats: WKT/WKT2, <authority>:<code>, or PROJ-string notation. See
#'   \link[terra]{crs}. Defaults to the recorded CRS, else `"EPSG:4326"`.
#' @param id Optional character string naming the column that identifies the
#'   units. When `NULL`, the recorded key, `ID`, or `ID_adm_div` is used.
#'
#' @returns A \link[terra]{SpatVector} of points with one variable, the
#'   location identifier.
#'
#' @export
#'
#' @seealso [terra::vect]
#'
#' @examples
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' georef_coord(coord)
georef_coord <- function(df, geom = NULL, crs = NULL, id = NULL) {
    meta <- c4e_meta(df) %||% empty_meta()
    key <- resolve_key(df, id)

    if (is.null(geom)) {
        if (is.null(meta$survey$lon) || is.null(meta$survey$lat)) {
            cli::cli_abort(c(
                "{.arg geom} is missing, and {.arg df} records no coordinate
                 columns.",
                "i" = "Give {.code geom = c(\"lon\", \"lat\")}, or prepare the
                       table with {.fn prepare_coord}."
            ))
        }
        geom <- c(meta$survey$lon, meta$survey$lat)
    }
    if (is.null(crs)) {
        crs <- meta$crs %||% {
            c4e_inform("Taking the coordinates as longitude and latitude in
                        {.val EPSG:4326}; give {.arg crs} otherwise.")
            "EPSG:4326"
        }
    }

    tibble::as_tibble(df) |>
        dplyr::distinct(dplyr::pick(dplyr::all_of(c(key, geom)))) |>
        terra::vect(crs = crs, geom = geom)
}
