#' The dates a window specification resolves to
#'
#' Turns a window from [window_lag()], [window_season()], [window_calendar()],
#' [window_fixed()] or [window_since()] into the dates it covers, for every
#' location and interview date in `data`: one row per key, interview and lag.
#'
#' [summarise_by_interview()] resolves windows this way before summarising.
#' The same resolution is exported here for the cases that do not go through a
#' summary: cutting a daily series to each household's growing season, joining
#' windows onto a table of one's own, or checking what a window actually
#' covers before relying on it.
#'
#' Windows are half-open, `(w_start, w_end]`: a day equal to `w_start` falls
#' outside the window and a day equal to `w_end` falls inside it, so that
#' consecutive lags of the same window neither overlap nor leave a gap.
#'
#' Rows are dropped rather than returned with missing dates when they have no
#' interview date, no key, or -- for [window_calendar()] and [window_since()]
#' -- no bounds. Resolving a window is therefore not a row-preserving
#' operation, and the result is distinct over the key and the interview date:
#' households sharing both share a window.
#'
#' The season bounds of [window_calendar()], and the event date of
#' [window_since()], are not arguments here. The window object already records
#' which columns of `data` hold them, so naming them twice is not possible.
#'
#' @param window A window from [window_lag()], [window_lags()],
#'   [window_season()], [window_calendar()], [window_fixed()] or
#'   [window_since()].
#' @param data A data frame holding the key column, the interview dates, and
#'   the columns named by `window` where it names any.
#' @param interview <[`data-masking`][rlang::args_data_masking]> The column
#'   holding the interview date. Taken from the metadata after
#'   [prepare_coord()].
#' @param by Name of the column linking `data` to the indicator table, as a
#'   string. Taken from `data`'s metadata where it records a key.
#'
#' @return A tibble with one row per distinct key, interview date and lag:
#'   the key column under its own name, `interview`, `lag` (`0` for the window
#'   closest to the interview, counting up as they recede), `w_start` and
#'   `w_end`.
#'
#' @seealso [window_lag()] for the window objects, [summarise_by_interview()]
#'   for summarising a series over them.
#' @family survey
#' @export
#'
#' @examples
#' survey <- tibble::tibble(
#'     division  = c("a", "b"),
#'     interview = as.Date(c("2023-11-20", "2023-06-15")),
#'     sos       = c(92, 92),
#'     eos       = c(297, 297)
#' )
#'
#' # the twelve months before each interview
#' window_dates(window_lag("1 year"), survey, interview, by = "division")
#'
#' # the last growing season to have closed before each interview: division b
#' # was interviewed inside the 2023 season, so it takes 2022's
#' window_dates(window_calendar(sos, eos), survey, interview, by = "division")
window_dates <- function(window, data, interview = NULL, by = NULL) {
    if (!inherits(window, "c4e_window")) {
        cli::cli_abort(c(
            "{.arg window} must be a window object, not
             {.obj_type_friendly {window}}.",
            "i" = "Build one with {.fn window_lag}, {.fn window_season},
                   {.fn window_calendar}, {.fn window_fixed} or
                   {.fn window_since}."))
    }
    meta <- c4e_meta(data) %||% empty_meta()
    tbl <- tibble::as_tibble(data)

    by <- by %||% meta$key
    if (is.null(by)) {
        cli::cli_abort(c(
            "Give {.arg by}: the column linking {.arg data} to the indicator
             table.",
            "i" = "It is only inferred when {.arg data} carries a key in its
                   metadata."))
    }
    if (!by %in% names(tbl)) {
        cli::cli_abort("{.arg data} has no {.field {by}} column.")
    }

    interview_quo <- rlang::enquo(interview)
    if (rlang::quo_is_null(interview_quo)) {
        if (is.null(meta$survey$interview)) {
            cli::cli_abort(c(
                "Give {.arg interview}: the column holding the interview date.",
                "i" = "It is only inferred after {.fn prepare_coord}."))
        }
        interview_quo <- rlang::quo(.data[[!!meta$survey$interview]])
    }

    keys <- dplyr::transmute(
        tbl,
        .by_key = .data[[by]],
        .interview = parse_date_label(!!interview_quo))

    needed <- switch(window$type,
                     since = window$event,
                     calendar = c(window$start, window$end),
                     character())
    absent <- setdiff(needed, names(tbl))
    if (length(absent) > 0) {
        builder <- if (identical(window$type, "since")) {
            "window_since"
        } else {
            "window_calendar"
        }
        cli::cli_abort("{.arg data} has no {.field {absent}} column{?s}, which
                        {.fn {builder}} needs.")
    }
    if (identical(window$type, "since")) {
        keys$.event <- parse_date_label(tbl[[window$event]])
    }
    if (identical(window$type, "calendar")) {
        keys$.sos <- as.numeric(tbl[[window$start]])
        keys$.eos <- as.numeric(tbl[[window$end]])
    }

    window_frame(window, keys) |>
        dplyr::select(dplyr::all_of(c(".by_key", ".interview")),
                      "lag", "w_start", "w_end") |>
        dplyr::rename(!!by := ".by_key", "interview" = ".interview")
}
