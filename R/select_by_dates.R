#' Select time observations based on date range
#'
#' Keeps the observations between two dates: the date columns of a wide
#' table, or the layers of a raster.
#'
#' @param x A data frame with time-series data in wide format (one column
#'   per date), a `c4e_tbl`, or a `SpatRaster` with dates.
#' @param from character. A string representing the start date (optional).
#' @param to character. A string representing the end date (optional).
#' @param ... Unused.
#'
#' @return `x` restricted to the dates between `from` and `to`. Columns that
#'   are not dates are kept. A `c4e_tbl` records the new date range, and a
#'   raster keeps its context.
#'
#' @details
#' The function requires both or just one between the starting date,
#' `from`, and the end date `to`. If both are provide the the function select
#' between the two dates. If only `from` is provided the function selects all
#' date after. If only `to` is provided the function selects all date
#' before. If none are provided returns the data unchanged.
#'
#' Dates may be truncated, e.g. `"2022"` or `"2022-06"`. Date columns are
#' those whose name starts with a year, optionally after an `X`, so a column
#' such as `MAX_2020` is not taken for a date.
#'
#' @export
#'
#' @examples
#' df <- data.frame(X2022.12 = c(100, 200),
#'                  X2022.06 = c(150, 250))
#'
#' select_by_dates(df, from = "2022-06-01", to = "2022-12-31")
#'
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "climatic4economist"))
#' select_by_dates(tmax, from = "2023-06-01", to = "2023-06-30")
select_by_dates <- function(x, from = NULL, to = NULL, ...) {
    UseMethod("select_by_dates")
}

#' @rdname select_by_dates
#' @export
select_by_dates.data.frame <- function(x, from = NULL, to = NULL, ...) {
    started <- Sys.time()
    col_names <- names(x)
    is_date  <- grepl(date_pattern(), col_names)
    id_col   <- col_names[!is_date]
    date_col <- col_names[is_date]
    dates <- to_date(date_col) |>
        substr(1, 10) |>
        lubridate::ymd(truncated = 2, quiet = TRUE)

    keep <- dates_between(dates, from, to)
    out <- dplyr::select(x, dplyr::all_of(id_col), dplyr::all_of(date_col[keep]))

    if (is_c4e_tbl(out)) {
        kept <- dates[keep]
        meta <- modify_meta(c4e_meta(out), list(
            date_range = if (length(kept) > 0) range(kept)
        ))
        meta <- c4e_record(meta, "select_by_dates", list(from = from, to = to),
                           started)
        out <- new_c4e_tbl(out, meta)
    }
    out
}

#' @rdname select_by_dates
#' @export
select_by_dates.SpatRaster <- function(x, from = NULL, to = NULL, ...) {
    keep <- dates_between(layer_dates(x), from, to)
    if (!any(keep)) {
        cli::cli_abort("No layer of {.arg x} falls between {.arg from} and {.arg to}.")
    }
    keep_raster_meta(x[[which(keep)]], x)
}

#' Which dates fall between two truncated dates, inclusive
#' @noRd
dates_between <- function(dates, from = NULL, to = NULL) {
    keep <- !is.na(dates)
    if (!is.null(from)) {
        keep <- keep & dates >= lubridate::ymd(from, truncated = 2)
    }
    if (!is.null(to)) {
        keep <- keep & dates <= lubridate::ymd(to, truncated = 2)
    }
    keep
}

#' The dates of a raster's layers, from terra or from the layer names
#' @noRd
layer_dates <- function(x, call = rlang::caller_env()) {
    if (terra::has.time(x) && !all(is.na(terra::time(x)))) {
        return(as.Date(format(terra::time(x), "%Y-%m-%d")))
    }
    dates <- dates_from_names(names(x))
    if (is.null(dates)) {
        cli::cli_abort(c(
            "The layers of {.arg x} have no dates.",
            "i" = "Read it with {.fn read_climate}, or set {.code terra::time(x)}."
        ), call = call)
    }
    dates
}
