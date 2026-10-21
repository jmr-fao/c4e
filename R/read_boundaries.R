#' Read administrative boundaries
#'
#' One entry point for the boundary datasets the package knows: FAO GAUL and
#' geoBoundaries. Both return the same layout, so later steps do not depend
#' on the source: one row per division, a sequential `ID_adm_div`, the names
#' `adm_div_1`, `adm_div_2`, ... and the country `iso`.
#'
#' @param path Folder containing the boundary files, organised as described
#'   in `read_GAUL()` and `read_geoBoundaries()`.
#' @param iso ISO 3166-1 alpha-3 country code(s).
#' @param level Administrative level, `1` or `2`.
#' @param source `"gaul"` or `"geoboundaries"`.
#' @param file_format File extension of the boundary files.
#'
#' @return A `SpatVector`, or a named list of them when `iso` has several
#'   codes.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' adm2 <- read_boundaries("path/to/GAUL", iso = "MWI", level = 2)
#' }
read_boundaries <- function(path, iso, level = 2,
                            source = c("gaul", "geoboundaries"),
                            file_format = "geojson") {
    source <- rlang::arg_match(source)
    reader <- switch(source,
                     gaul          = read_GAUL,
                     geoboundaries = read_geoBoundaries)
    reader(path, iso = iso, lvl = level, file_format = file_format)
}
