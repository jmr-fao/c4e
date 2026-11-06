# Was this window unusual for this place? (plan 11.5)
#
# The window summaries of an earlier step, run with lags, hold the same
# window in each earlier year at the same location. This compares the window
# a survey unit lived through with those, which is a different question from
# calc_percentile(): that ranks a day among days, this ranks a season among
# seasons.

#' How unusual a window was, against the same window in earlier years
#'
#' Takes the output of [summarise_by_interview()] run with lags and compares
#' lag 0 — the window before the interview — with the same window at the same
#' location in the baseline years: the primary season's rainfall against past
#' primary seasons, not against the year-round average.
#'
#' Two forms, both returned by default:
#'
#' * `"pctl"`: the share of baseline windows at or below this one, 0 to 100.
#'   It assumes no distribution, which matters because season totals are
#'   right-skewed: a threshold of *z* < −1 catches far fewer dry seasons than
#'   a normal distribution implies, and under-detects them worst in the
#'   driest places. A percentile also means the same thing in two countries,
#'   where a z-score does not.
#' * `"z"`: the window's distance from the baseline mean in baseline standard
#'   deviations. Retained because the literature reports rainfall z-scores.
#'
#' Within one location the percentile is a monotone transform of the
#' z-score, so with location fixed effects the two rank units identically
#' and differ only in shape. The gain from the percentile appears when
#' pooling across locations.
#'
#' For a fitted-distribution version of the same idea on monthly data, see
#' [calc_std_index()], which is SPI and SPEI.
#'
#' @param x A summary table from [summarise_by_interview()], run with lags —
#'   see [window_lags()]. It must hold `lag` and the window bounds, which
#'   that function returns.
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> The columns to
#'   take anomalies of; by default every summary column of `x`.
#' @param baseline The years the baseline is drawn from, as two numbers
#'   (`c(1981, 2020)`) or two dates, matched on the year each window ends
#'   in. By default every lag other than 0, however far back the window
#'   reached.
#' @param forms `"pctl"`, `"z"`, or both.
#' @param min_years The fewest baseline windows an anomaly may be built on;
#'   a unit with fewer gets `NA` rather than a number resting on a handful
#'   of years.
#' @param id Optional name of the unit identifier column.
#' @param label Optional name shown in progress messages.
#'
#' @return A `c4e_tbl` with one row per survey unit: the identifier,
#'   `baseline_n` (how many baseline windows it was built on) and one column
#'   per input column and form, `pre_total_pctl` and `pre_total_z` for
#'   `pre_total`.
#'
#' @seealso [summarise_by_interview()], [window_lags()], [calc_std_index()]
#' @family indicators
#' @export
#'
#' @examples
#' tmax <- read_climate(system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' survey$interview <- as.Date(survey$interview)
#' coord <- prepare_coord(survey, lat, lon, id = hhid, interview = interview)
#'
#' hot <- extract_by_coord(tmax, georef_coord(coord)) |>
#'   convert_unit("C") |>
#'   calc_threshold_day(above = 30)
#'
#' summarise_by_interview(coord, hot, window = window_lags(window_lag("1 year"), 0:2)) |>
#'   calc_anomaly(min_years = 2)
calc_anomaly <- function(x, cols = NULL, baseline = NULL,
                         forms = c("pctl", "z"), min_years = 10,
                         id = NULL, label = NULL) {
    started <- Sys.time()
    meta <- c4e_meta(x) %||% empty_meta()
    tbl <- tibble::as_tibble(x)

    forms <- rlang::arg_match(forms, c("pctl", "z"), multiple = TRUE)
    key <- id %||% meta$key
    if (is.null(key) || !key %in% names(tbl)) {
        cli::cli_abort(c("Give {.arg id}, the column identifying the survey units.",
                         i = "{.arg x} should come from {.fn summarise_by_interview}."))
    }
    if (!"lag" %in% names(tbl)) {
        cli::cli_abort(c("{.arg x} has no {.field lag} column.",
                         i = "Run {.fn summarise_by_interview} over several
                              periods first, see {.fn window_lags}."))
    }
    if (!all(c("w_start", "w_end") %in% names(tbl))) {
        cli::cli_abort(c("{.arg x} does not carry its window bounds.",
                         i = "They come from {.fn summarise_by_interview};
                              a table built by hand needs
                              {.field w_start} and {.field w_end}."))
    }
    if (max(tbl$lag) < 1) {
        cli::cli_abort(c("{.arg x} holds only lag 0, so there is no baseline
                          to compare it with.",
                         i = "Reach back with {.fn window_lags}."))
    }

    reserved <- c(key, "lag", "w_start", "w_end", "baseline_n",
                  meta$survey_cols)
    value_cols <- if (rlang::quo_is_null(rlang::enquo(cols))) {
        setdiff(names(tbl)[vapply(tbl, is.numeric, logical(1))], reserved)
    } else {
        names(dplyr::select(tbl, {{ cols }}))
    }
    value_cols <- setdiff(value_cols, reserved)
    if (length(value_cols) == 0) {
        cli::cli_abort("{.arg x} has no summary columns to take anomalies of.")
    }

    years <- baseline_years(baseline)
    in_baseline <- if (is.null(years)) {
        tbl$lag > 0
    } else {
        year <- lubridate::year(tbl$w_end)
        tbl$lag > 0 & year >= years[1] & year <= years[2]
    }
    kept <- tbl$lag == 0 | in_baseline
    if (!any(in_baseline)) {
        cli::cli_abort(c("No window falls in the baseline.",
                         i = "The windows of {.arg x} end between
                              {.val {as.character(min(tbl$w_end))}} and
                              {.val {as.character(max(tbl$w_end))}}."))
    }
    if (!is.null(label)) {
        c4e_progress_step("Anomalies of {label}")
    }

    work <- tbl[kept, c(key, "lag", value_cols), drop = FALSE]
    work$.base <- !(work$lag == 0)

    exprs <- list(baseline_n = rlang::expr(sum(.data$.base)))
    for (col in value_cols) {
        value <- rlang::expr(.data[[!!col]])
        if ("pctl" %in% forms) {
            exprs[[paste0(col, "_pctl")]] <-
                rlang::expr(anomaly_rank(!!value, .data$.base, !!min_years))
        }
        if ("z" %in% forms) {
            exprs[[paste0(col, "_z")]] <-
                rlang::expr(anomaly_score(!!value, .data$.base, !!min_years))
        }
    }

    out <- dplyr::summarise(work, !!!exprs, .by = dplyr::all_of(key))

    entries <- list()
    for (col in value_cols) {
        source <- meta$indicators[[col]] %||% list()
        for (form in forms) {
            entries[[paste0(col, "_", form)]] <- new_indicator(
                ## `of` is the kind the column was built from, taken past the
                ## aggregation step so the label describes the indicator
                ## itself rather than the summary of it
                "anomaly", base = col, stat = form,
                of = source$of %||% source$kind,
                direction = source$direction, threshold = source$threshold,
                p = source$p, min_spell = source$min_spell,
                variable = source$variable %||% meta$variable,
                unit = if (identical(form, "pctl")) "%" else "sd",
                step = source$step, window = meta$window$type)
        }
    }

    ## the baseline itself is not a metadata field; c4e_record() below keeps
    ## it in the history, where the call's own arguments live
    new_meta <- modify_meta(meta, list(
        unit_cols = NULL, shape = "summary", indicators = entries))
    new_meta <- c4e_record(new_meta, "calc_anomaly",
                           list(baseline = years, forms = forms,
                                min_years = min_years), started)
    new_c4e_tbl(out, prune_meta(new_meta, names(out)))
}

#' The baseline bounds as two years, or NULL for every lag
#' @noRd
baseline_years <- function(baseline, call = rlang::caller_env()) {
    if (is.null(baseline)) {
        return(NULL)
    }
    if (length(baseline) != 2) {
        cli::cli_abort("{.arg baseline} must be two years or two dates.",
                       call = call)
    }
    years <- if (is.numeric(baseline) && all(baseline > 1000 & baseline < 3000)) {
        as.integer(baseline)
    } else {
        lubridate::year(lubridate::as_date(baseline))
    }
    if (anyNA(years) || years[2] < years[1]) {
        cli::cli_abort("{.arg baseline} must run from the earlier year to the
                        later one.", call = call)
    }
    years
}

#' The share of the baseline at or below this window, 0 to 100
#' @noRd
anomaly_rank <- function(value, base, min_years) {
    now <- value[!base]
    ref <- value[base & !is.na(value)]
    if (length(now) != 1 || is.na(now) || length(ref) < min_years) {
        return(NA_real_)
    }
    100 * mean(ref <= now)
}

#' This window's distance from the baseline mean, in baseline sds
#' @noRd
anomaly_score <- function(value, base, min_years) {
    now <- value[!base]
    ref <- value[base & !is.na(value)]
    if (length(now) != 1 || is.na(now) || length(ref) < min_years) {
        return(NA_real_)
    }
    spread <- stats::sd(ref)
    if (is.na(spread) || spread == 0) {
        return(NA_real_)
    }
    (now - mean(ref)) / spread
}
