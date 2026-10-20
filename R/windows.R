# Reference windows before each interview (plan §11.3).
#
# A window object describes which dates count for a survey unit; window_frame()
# turns it into one row per location, interview date and lag with the bounds
# (w_start, w_end]: dates after w_start, up to and including w_end.

#' Reference windows for survey summaries
#'
#' Describe the period before each interview over which
#' [summarise_by_interview()] summarises the indicators.
#'
#' * `window_lag()`: consecutive periods of `interval` before the interview,
#'   e.g. the 12 months before it (lag 0) and the 12 months before those
#'   (lag 1). The interview day itself is never included.
#' * `window_season()`: the last season that ended before the interview,
#'   and earlier ones with `years_back`, e.g. the June to September rains. A
#'   season may cross the new year (`"Nov"` to `"Feb"`).
#' * `window_fixed()`: the same calendar period for everyone.
#' * `window_since()`: from a date recorded for each household, such as
#'   planting or a shock, up to the day before the interview.
#'
#' @param interval Length of each lag, e.g. `"1 year"`, `"6 months"`,
#'   `"30 days"`.
#' @param n_lags Highest lag; `0` gives only the period just before the
#'   interview.
#' @param start_month,end_month Season bounds: numbers, abbreviations or
#'   month names.
#' @param years_back Which past seasons: `0` is the last one, `0:2` the last
#'   three.
#' @param from,to Dates of a fixed window, inclusive.
#' @param event <[`data-masking`][rlang::args_data_masking]> Column of the
#'   survey with the start date of each household's window.
#'
#' @return A `c4e_window` object.
#'
#' @seealso [summarise_by_interview()]
#' @export
#'
#' @examples
#' window_lag("1 year", n_lags = 2)
#' window_season("Jun", "Sep", years_back = 0:1)
#' window_fixed("2022-01-01", "2022-12-31")
window_lag <- function(interval = "1 year", n_lags = 0) {
    parse_interval(interval)
    if (!is.numeric(n_lags) || length(n_lags) != 1 || n_lags < 0) {
        cli::cli_abort("{.arg n_lags} must be a single number, 0 or more.")
    }
    new_window("lag", interval = interval, n_lags = as.integer(n_lags))
}

#' @rdname window_lag
#' @export
window_season <- function(start_month, end_month, years_back = 0) {
    new_window("season", start_month = month_number(start_month),
               end_month = month_number(end_month),
               years_back = as.integer(years_back))
}

#' @rdname window_lag
#' @export
window_fixed <- function(from, to) {
    from <- lubridate::as_date(from)
    to <- lubridate::as_date(to)
    if (is.na(from) || is.na(to) || to < from) {
        cli::cli_abort("{.arg from} and {.arg to} must be dates, with {.arg to}
                        not before {.arg from}.")
    }
    new_window("fixed", from = from, to = to)
}

#' @rdname window_lag
#' @export
window_since <- function(event) {
    new_window("since", event = rlang::as_name(rlang::enquo(event)))
}

new_window <- function(type, ...) {
    structure(list(type = type, ...), class = "c4e_window")
}

#' @export
print.c4e_window <- function(x, ...) {
    cli::cat_line("<c4e window: ", describe_window(x), ">")
    invisible(x)
}

#' A one-line description of a window
#' @noRd
describe_window <- function(window) {
    switch(window$type,
           lag    = paste0(window$interval, " before the interview",
                           if (window$n_lags > 0) paste0(", lags 0 to ", window$n_lags)),
           season = paste0("season ", month.abb[window$start_month], " to ",
                           month.abb[window$end_month], ", ",
                           paste(window$years_back, collapse = ", "),
                           " season(s) back"),
           fixed  = paste0("from ", window$from, " to ", window$to),
           since  = paste0("from ", window$event, " to the interview"))
}

#' Window bounds for each location and interview date
#'
#' @param window A `c4e_window`.
#' @param keys A data frame with `.by_key`, `.interview` and, for
#'   `window_since()`, `.event`.
#' @return `keys` (distinct) crossed with the lags, with `lag`, `w_start`
#'   and `w_end`.
#' @noRd
window_frame <- function(window, keys) {
    keys <- dplyr::distinct(tibble::as_tibble(keys))
    keys <- dplyr::filter(keys, !is.na(.data$.interview), !is.na(.data$.by_key))
    switch(window$type,
           lag = {
               parsed <- parse_interval(window$interval)
               make_lag_windows(keys, .data$.by_key, .data$.interview,
                                n_period = parsed$n, period = parsed$unit,
                                n_lags = window$n_lags)
           },
           season = season_windows(keys, window),
           fixed = dplyr::mutate(keys, lag = 0L, w_start = window$from - 1L,
                                 w_end = window$to),
           since = keys |>
               dplyr::filter(!is.na(.data$.event)) |>
               dplyr::mutate(lag = 0L, w_start = .data$.event,
                             w_end = .data$.interview - 1L))
}

#' The last complete seasons before each interview
#' @noRd
season_windows <- function(keys, window) {
    start_month <- window$start_month
    end_month <- window$end_month
    season_end <- function(year) {
        lubridate::ceiling_date(lubridate::make_date(year, end_month, 1), "month") - 1L
    }
    season_start <- function(year) {
        lubridate::make_date(if (start_month <= end_month) year else year - 1L,
                             start_month, 1)
    }
    year_now <- lubridate::year(keys$.interview)
    last_year <- ifelse(season_end(year_now) < keys$.interview, year_now, year_now - 1L)

    tidyr::expand_grid(dplyr::mutate(keys, .last = last_year),
                       lag = window$years_back) |>
        dplyr::mutate(w_start = season_start(.data$.last - .data$lag) - 1L,
                      w_end   = season_end(.data$.last - .data$lag)) |>
        dplyr::select(-".last")
}

#' How many observations a window should hold at a time step
#'
#' Windows are (w_start, w_end]. Months and years count the month or year
#' starts inside the window, which is where monthly and yearly data are
#' dated.
#' @noRd
expected_count <- function(w_start, w_end, step) {
    count <- switch(step %||% "day",
                    hour  = as.numeric(w_end - w_start) * 24,
                    day   = as.numeric(w_end - w_start),
                    month = (12 * lubridate::year(w_end) + lubridate::month(w_end)) -
                        (12 * lubridate::year(w_start) + lubridate::month(w_start)),
                    year  = lubridate::year(w_end) - lubridate::year(w_start),
                    as.numeric(w_end - w_start))
    pmax(count, 0)
}
