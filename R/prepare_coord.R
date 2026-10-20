#' Prepare ID for unique occurrences
#'
#' Adds an `ID` column identifying each unique location, and records which
#' columns hold the coordinates, the household identifier and the interview
#' date, so later steps ([georef_coord()], [summarise_by_interview()]) find
#' them without being told again.
#'
#' By default the ID is built from the coordinates themselves (longitude and
#' latitude rounded to `digits` decimals, e.g. `"30.12340_-0.54320"`), so the
#' same location gets the same ID in every wave, subset and run. With
#' `id_rule = "sequence"` the IDs are `"1"`, `"2"`, ... in the order of the
#' sorted coordinates, as in v1; they change whenever the set of locations
#' changes.
#'
#' Rows are sorted by latitude and longitude.
#'
#' @param df A data frame.
#' @param lat_var <data-masking> variable with the latitude coordinate
#' @param lon_var <data-masking> variable with the longitude coordinate
#' @param id <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional column
#'   identifying the survey units (households), recorded for later steps.
#' @param interview <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional
#'   column with the interview dates, recorded for later steps.
#' @param id_rule `"coordinates"` (stable IDs) or `"sequence"`.
#' @param digits Decimals of the coordinates in a coordinate ID.
#'
#' @returns A `c4e_tbl`: `df` with an `ID` column first, keyed by `ID`, with
#'   the survey's columns recorded.
#'
#' @export
#'
#' @examples
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "c4e"))
#' prepare_coord(survey, lat_var = lat, lon_var = lon, id = hhid,
#'               interview = interview)
prepare_coord <- function(df, lat_var, lon_var, id = NULL, interview = NULL,
                          id_rule = c("coordinates", "sequence"), digits = 5) {
    started <- Sys.time()
    id_rule <- rlang::arg_match(id_rule)
    lat_name <- rlang::as_name(rlang::enquo(lat_var))
    lon_name <- rlang::as_name(rlang::enquo(lon_var))
    id_name <- optional_column(df, rlang::enquo(id), "id")
    interview_name <- optional_column(df, rlang::enquo(interview), "interview")

    data <- tibble::as_tibble(df) |>
        dplyr::arrange(.data[[lat_name]], .data[[lon_name]])
    lat <- data[[lat_name]]
    lon <- data[[lon_name]]
    ids <- if (id_rule == "coordinates") {
        coordinate_id(lon, lat, digits)
    } else {
        as.character(vctrs::vec_group_id(data[c(lat_name, lon_name)]))
    }
    data <- tibble::add_column(data, ID = ids, .before = 1)

    meta <- list(
        key     = "ID",
        id_rule = id_rule,
        survey  = purrr::compact(list(lon = lon_name, lat = lat_name,
                                      id = id_name, interview = interview_name))
    )
    meta <- c4e_record(modify_meta(empty_meta(), meta), "prepare_coord",
                       list(id_rule = id_rule), started)
    new_c4e_tbl(data, meta)
}

#' "lon_lat" with a fixed number of decimals; NA when a coordinate is missing
#' @noRd
coordinate_id <- function(lon, lat, digits) {
    ids <- paste0(formatC(round(lon, digits), format = "f", digits = digits), "_",
                  formatC(round(lat, digits), format = "f", digits = digits))
    ids[is.na(lon) | is.na(lat)] <- NA_character_
    ids
}

#' The name of a column given as tidy-select, or NULL when not given
#' @noRd
optional_column <- function(df, quo, arg, call = rlang::caller_env()) {
    if (rlang::quo_is_null(quo)) {
        return(NULL)
    }
    selected <- names(dplyr::select(tibble::as_tibble(df), !!quo))
    if (length(selected) != 1) {
        cli::cli_abort("{.arg {arg}} must name exactly one column.", call = call)
    }
    selected
}
