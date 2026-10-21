#' Read Sub National Administrative Divisions from GAUL Files
#'
#' This function reads and processes administrative boundaries at at any given
#' level for one or more countries from a given directory path.
#' The function uses `terra` to load the vector files and `tidyterra` for cleaning
#' and renaming columns.
#' The data are obtained from [GAUL](https://data.apps.fao.org/catalog/organization/administrative-boundaries-fao)
#'
#' @param path_to_files A character string specifying the path where the country folders
#'        containing GeoJSON administrative division files are stored.
#' @param iso A character vector with one or more ISO 3-letter country codes (e.g., `"KEN"`, `"UGA"`).
#' @param lvl An integer specifying the desired level of administrative division to return:
#'        `1` for ADM1, or `2` for ADM2 (default).
#' @param file_format A character string with the file extension of the boundary
#'        files (default is `"geojson"`).
#'
#' @return A named list of `SpatVector` objects, each corresponding to one country.
#'         - If `lvl = 1`, the function returns ADM1 polygons with columns: `adm_div_1`, `iso`, `lvl`.
#'         - If `lvl = 2`, it returns intersected ADM2 polygons including the corresponding ADM1 divisions,
#'           with columns: `iso`, `adm_div_1`, `adm_div_2`, `lvl`.
#'
#' @details
#' The function expects a directory structure like:
#' ```
#' path_to_data/
#' ├── KEN/
#' │   ├── .../KEN_ADM1.geojson
#' │   └── .../KEN_ADM2.geojson
#' ├── UGA/
#' │   ├── .../UGA_ADM1.geojson
#' │   └── .../UGA_ADM2.geojson
#' ```
#' It performs intersection between ADM2 and ADM1 shapes to ensure hierarchical alignment.
#'
#' @noRd
#'
read_GAUL <- function(path_to_files, iso, lvl = 2, file_format = "geojson") {
    if (length(iso) > 1) iso <- paste(iso, collapse = "|")
    iso_name <- sort(unlist(strsplit(iso, "|", fixed = TRUE)))

    tidy <- function(x) {
        x <- vect_rename(x, c(iso = "iso3_code", adm_div_1 = "gaul1_name",
                              adm_div_2 = "gaul2_name"))
        x <- x[, grepl("adm_div|iso", names(x))]
        with_adm_id(x)
    }
    out <- list.files(path_to_files, pattern = iso, full.names = TRUE) |>
        lapply(list.files, full.names = TRUE, pattern = paste0("ADM", lvl)) |>
        lapply(list.files, pattern = paste0("ADM[012]\\.", file_format), full.names = TRUE) |>
        lapply(terra::vect) |>
        lapply(tidy) |>
        stats::setNames(iso_name)

    if (length(out) == 1) return(out[[1]])
    out
}
