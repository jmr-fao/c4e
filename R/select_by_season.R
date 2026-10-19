#' Select Columns of a Data Frame Corresponding to a Seasonal Period
#'
#' Keeps the observations that fall within a seasonal range of months: the
#' date columns of a wide table, or the layers of a raster. Identifier
#' columns are kept.
#'
#' @param x A `data.frame` or `tibble` with identifier columns and date-labeled
#'   columns (e.g. "2021-04-01", "X2022.07.15"), or a `SpatRaster` with dates.
#' @param start_month The starting month of the seasonal window. Can be provided
#'   as an integer (1 to 12), a month abbreviation (e.g., `"Apr"`), or a full
#'   month name (e.g., `"April"`).
#' @param end_month The ending month of the seasonal window. Same format as
#'   `start_month`.
#' @param ... Unused.
#'
#' @details
#' If `start_month <= end_month`, the function returns all observations
#' between those two months (inclusive). If `start_month > end_month`, the
#' season crosses the year boundary (e.g., November to February).
#'
#' Date columns are those whose name starts with a year, optionally after an
#' `X`.
#'
#' @return `x` restricted to the months of the season. A raster keeps its
#'   context.
#'
#' @examples
#' df <- data.frame(
#'   ID = 1,
#'   "2021-01-01" = 10,
#'   "2021-04-01" = 15,
#'   "2021-07-01" = 20,
#'   "2021-11-01" = 25,
#'   check.names = FALSE
#' )
#'
#' # Select April to July
#' select_by_season(df, "Apr", "Jul")
#'
#' # Select November to February (crosses year boundary)
#' select_by_season(df, 11, 2)
#'
#' @export
select_by_season <- function(x, start_month, end_month, ...) {
    UseMethod("select_by_season")
}

#' @rdname select_by_season
#' @export
select_by_season.data.frame <- function(x, start_month, end_month, ...) {
    col_names <- names(x)
    is_date  <- grepl(date_pattern(), col_names)
    id_col   <- col_names[!is_date]
    date_col <- col_names[is_date]
    months <- to_date(date_col) |>
        lubridate::ymd(truncated = 2, quiet = TRUE) |>
        lubridate::month()

    keep <- in_season(months, start_month, end_month)
    dplyr::select(x, dplyr::all_of(id_col), dplyr::all_of(date_col[keep]))
}

#' @rdname select_by_season
#' @export
select_by_season.SpatRaster <- function(x, start_month, end_month, ...) {
    months <- lubridate::month(layer_dates(x))
    keep <- in_season(months, start_month, end_month)
    if (!any(keep)) {
        cli::cli_abort("No layer of {.arg x} falls in the season.")
    }
    keep_raster_meta(x[[which(keep)]], x)
}

#' Which months fall in a season that may cross the year boundary
#' @noRd
in_season <- function(months, start_month, end_month) {
    sm <- month_number(start_month)
    em <- month_number(end_month)
    keep <- if (sm <= em) {
        months >= sm & months <= em
    } else {
        months >= sm | months <= em
    }
    keep & !is.na(keep)
}

#' Month number from a number, an abbreviation or a full name
#' @noRd
month_number <- function(m) {
    if (is.character(m)) {
        m <- tolower(m)
        number <- match(m, tolower(month.abb))
        number[is.na(number)] <- match(m[is.na(number)], tolower(month.name))
        if (anyNA(number)) {
            cli::cli_abort("Unknown month {.val {m}}.", call = NULL)
        }
        return(number)
    }
    as.integer(m)
}
