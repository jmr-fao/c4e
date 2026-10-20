#' Climatic parameters per unit
#'
#' Computes summary statistics of each unit's series, such as the long-run
#' mean and standard deviation of temperature, or the average yearly rainfall.
#'
#' With `period`, the statistics are first computed within each period and
#' then averaged across periods: `fn = list(total = sum), period = "year"`
#' gives the average yearly total. Periods are counted back from the last
#' date of the data, so the last period always ends on the last observation:
#' yearly periods are the 12-month windows ending there, monthly periods the
#' one-month windows. When the last date is not the end of December (yearly)
#' or of a month (monthly), a warning says so, because the windows then do
#' not follow calendar years or months.
#'
#' Columns are named `<prefix>_<statistic>_<suffix>`. The prefix defaults to
#' the variable recorded upstream (announced), so a temperature table gives
#' `tmax_mean`, `tmax_sd`.
#'
#' @section Monthly coverage:
#' With `period = "month"` a month represented by only a handful of days would
#' enter the average as though it were complete. `min_coverage` guards
#' against this by comparing the observations present in each window with the
#' number of days it spans. If no month reaches it, the function stops; the
#' most common cause is data already at monthly resolution, for which
#' `period = NULL` or `period = "year"` are the right choices. Monthly input
#' asked for monthly periods is refused at once.
#'
#' @param x A wide table from `extract_*()`, or a long table.
#' @param fn The statistics: a named list of functions
#'   (`list(avg = mean, total = sum)`), a character vector of function names
#'   (`c("mean", "sd")`) or a single function. Functions receive the values
#'   with any `NA`, so handle them as needed (`\(v) mean(v, na.rm = TRUE)`).
#' @param period `NULL` (all observations together), `"year"` or `"month"`.
#' @param min_coverage Number between 0 and 1: the share of a month's days
#'   that must be present for the month to count. Used only when
#'   `period = "month"`.
#' @param prefix Column name prefix; by default the variable, `FALSE` for
#'   none.
#' @param suffix Optional column name suffix.
#' @inheritParams calc_threshold_day
#'
#' @return A `c4e_tbl` with one row per unit: its identifiers and one column
#'   per statistic, registered with the statistic and period.
#'
#' @family indicators
#' @export
#'
#' @examples
#' df <- data.frame(
#'   ID = c(1, 2),
#'   `200101` = c(10, 20),
#'   `200102` = c(15, 25),
#'   `200201` = c(5, 15),
#'   `200202` = c(10, 20),
#'   check.names = FALSE
#' )
#'
#' # Mean across all observations
#' calc_par(df, fn = list(avg = mean))
#'
#' # Average of yearly totals
#' calc_par(df, fn = list(total = sum), period = "year")
calc_par <- function(x, fn, period = NULL, min_coverage = 0.8, prefix = NULL,
                     suffix = NULL, id = NULL, label = NULL, chunk = "auto") {
    started <- Sys.time()
    if (!is.numeric(min_coverage) || length(min_coverage) != 1 ||
        is.na(min_coverage) || min_coverage < 0 || min_coverage > 1) {
        cli::cli_abort("{.arg min_coverage} must be a single number between 0 and 1.")
    }
    if (!is.null(period) && !isTRUE(period %in% c("year", "month"))) {
        cli::cli_abort("Unsupported {.arg period} {.val {period}}. Use {.val year},
                        {.val month} or {.code NULL}.")
    }
    fns <- as_function_list(fn, rlang::enexpr(fn))

    if (is.null(c4e_meta(x))) {
        key <- resolve_key(x, id)
        known <- c("ID", "ID_adm_div", "x_cell", "y_cell", "coverage_fraction")
        x <- new_c4e_tbl(x, list(key = key,
                                 unit_cols = setdiff(intersect(known, names(x)), key)))
    }
    meta <- c4e_meta(x)
    step <- meta$time_step
    if (identical(period, "month") && identical(step, "month")) {
        cli::cli_abort(monthly_resolution_message())
    }
    prefix <- if (isFALSE(prefix)) NULL else {
        c4e_default(prefix, meta$variable, "prefix", field = "variable",
                    required = FALSE)
    }
    name_of <- function(stat) paste(c(prefix, stat, suffix), collapse = "_")

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        stats <- par_statistics(frame_matrix(frame, "value"), frame$dates, fns,
                                period, min_coverage)
        out <- frame$ids
        entries <- list()
        for (stat in names(stats)) {
            col <- name_of(stat)
            out[[col]] <- stats[[stat]]
            entries[[col]] <- new_indicator(
                "par", stat = stat, period = period %||% "all", base = "value",
                min_coverage = if (identical(period, "month")) min_coverage,
                variable = frame$meta$variable, unit = frame$meta$unit)
        }
        new_meta <- modify_meta(frame$meta, list(
            shape = "summary", date_col = NULL,
            date_range = range(frame$dates), indicators = entries))
        new_c4e_tbl(out, prune_meta(new_meta, names(out)))
    }

    run_indicator(x, compute, "calc_par",
                  args = list(fn = names(fns), period = period,
                              min_coverage = if (identical(period, "month")) min_coverage,
                              prefix = prefix, suffix = suffix),
                  n_new = length(fns), id = id, label = label, chunk = chunk,
                  started = started)
}

#' A named list of functions from a list, names, or a single function
#' @noRd
as_function_list <- function(fn, expr, call = rlang::caller_env()) {
    if (is.function(fn)) {
        name <- if (is.symbol(expr)) as.character(expr) else "fn"
        return(stats::setNames(list(fn), name))
    }
    if (is.character(fn)) {
        return(stats::setNames(lapply(fn, match.fun), fn))
    }
    if (is.list(fn) && length(fn) > 0 && all(vapply(fn, is.function, logical(1)))) {
        if (!rlang::is_named(fn)) {
            cli::cli_abort("Name every function in {.arg fn}, e.g.
                            {.code list(avg = mean)}.", call = call)
        }
        return(fn)
    }
    cli::cli_abort("{.arg fn} must be a named list of functions, function names
                    or a function.", call = call)
}

#' Each statistic per unit: over all values, or averaged across periods
#'
#' Periods are windows counted back from the last date with `find_lag()`, as
#' in v1. Monthly windows enter only when at least `min_coverage` of their
#' days are present.
#' @noRd
par_statistics <- function(values, dates, fns, period, min_coverage) {
    per_row <- function(m, f) {
        if (ncol(m) == 0) return(rep(NA_real_, nrow(m)))
        apply(m, 1, f)
    }
    if (is.null(period)) {
        return(lapply(fns, \(f) per_row(values, f)))
    }

    last_date <- max(dates)
    month_end <- last_date == lubridate::ceiling_date(last_date, "month") - 1
    if (period == "year" && (!month_end || lubridate::month(last_date) != 12)) {
        cli::cli_warn(c(
            "The last date ({last_date}) is not the last day of a month and/or not
             in December.",
            "i" = "Yearly periods are the 12-month windows ending on it, not
                   calendar years."
        ))
    }
    if (period == "month" && !month_end) {
        cli::cli_warn(c(
            "The last date ({last_date}) is not the last day of a month.",
            "i" = "Monthly periods are the one-month windows ending on it, not
                   calendar months."
        ))
    }

    groups <- find_lag(dates, last_date, unit = period)
    kept <- sort(unique(groups))
    if (period == "month") {
        n_days <- as.numeric(table(factor(groups, levels = kept)))
        expected <- vapply(kept, \(g) as.numeric(
            clock::add_months(last_date, as.integer(g), invalid = "previous") -
                clock::add_months(last_date, as.integer(g) - 1L, invalid = "previous")),
            numeric(1))
        complete <- n_days >= min_coverage * expected
        if (!any(complete)) {
            cli::cli_abort(incomplete_period_message(n_days, expected, min_coverage),
                           call = rlang::caller_env(2))
        }
        kept <- kept[complete]
    }

    lapply(fns, \(f) {
        within <- vapply(kept, \(g) per_row(values[, groups == g, drop = FALSE], f),
                         numeric(nrow(values)))
        within <- matrix(within, nrow(values), length(kept))
        rowMeans(within, na.rm = TRUE)
    })
}

monthly_resolution_message <- function() {
    c("No monthly period has enough observations to aggregate.",
      "x" = "The data is already at monthly resolution, so there is nothing to
             aggregate within a month.",
      "i" = "Use {.code period = NULL} to summarise across all observations, or
             {.code period = \"year\"} to average monthly values within each
             year.")
}

#' Explain why no monthly window survived the coverage filter
#' @noRd
incomplete_period_message <- function(n_days, expected, min_coverage) {
    if (all(n_days == 1)) {
        return(monthly_resolution_message())
    }
    # the numbers go into the text here: cli evaluates `{}` in the caller
    best <- format(round(max(n_days / expected), 2))
    c(paste0("No monthly period reaches the required coverage of ",
             format(min_coverage), "."),
      "i" = paste0("The most complete period covers ", best, " of its days.
                    Lower {.arg min_coverage} to accept partial months, or check
                    the input for gaps."))
}
