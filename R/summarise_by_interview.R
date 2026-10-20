#' Summarise indicators over each household's reference period
#'
#' For every survey unit (household), summarises the daily (or monthly)
#' indicators of its location over the window before its interview: the
#' number of hot days in the 12 months before the interview, the longest dry
#' spell in the last rainy season, and so on. Replaces
#' [extr_day_by_interview()], [extr_spell_by_interview()],
#' [extr_day_index()] and [extr_spell_index()].
#'
#' The summaries follow the kind of each indicator in the registry: flags
#' and excesses are summed (days, degree-days), spells give their maximum,
#' mean, sum and count, standardised indices their mean. `stats` changes
#' this per kind.
#'
#' A window with less than `min_coverage` of its days (months for monthly
#' data) present in the data gives `NA` rather than a count that looks
#' complete but is not, for example a window reaching before the start of the
#' data. Households without an interview date are left out and counted in a
#' message.
#'
#' The computation runs once per location and interview date and is then
#' given to every household sharing them, and it is split by location when
#' it would exceed the memory budget.
#'
#' @param survey The survey, typically from [prepare_coord()].
#' @param x A long indicator table, e.g. from [calc_threshold_day()] and
#'   [calc_spell()].
#' @param window A window from [window_lag()], [window_season()],
#'   [window_fixed()] or [window_since()].
#' @param interval,n_lags Shortcut for `window = window_lag(interval,
#'   n_lags)`.
#' @param by Column linking the survey to `x`; by default the key of `x`.
#' @param id <[`data-masking`][rlang::args_data_masking]> Column identifying
#'   the survey units; by default the one recorded by [prepare_coord()].
#' @param interview <[`data-masking`][rlang::args_data_masking]> Interview
#'   dates: a column, or one date for everyone; by default the recorded
#'   column.
#' @param extra_col <[`tidy-select`][dplyr::dplyr_tidy_select]> Survey
#'   columns to carry into the result.
#' @param stats Optional named list of statistics per kind of indicator,
#'   e.g. `list(flag = c("sum", "mean"), spell = "max")`. Statistics: `"sum"`,
#'   `"mean"`, `"max"`, `"min"`, `"n"` (number of non-missing values).
#' @param min_coverage Share of the window that must be covered by data.
#' @inheritParams calc_threshold_day
#'
#' @return A `c4e_tbl` with one row per survey unit and lag: the unit
#'   identifier, `lag`, the extra columns and one column per indicator and
#'   statistic (`day_abv_30_sum`, `spell_abv_30_max`), registered with the
#'   window.
#'
#' @seealso [window_lag()], [summarise_by_period()]
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
#'   calc_threshold_day(above = 30) |>
#'   calc_spell()
#'
#' summarise_by_interview(coord, hot, interval = "1 year", n_lags = 1)
summarise_by_interview <- function(survey, x, window = NULL, interval = NULL,
                                   n_lags = 0, by = NULL, id = NULL,
                                   interview = NULL, extra_col = NULL,
                                   stats = NULL, min_coverage = 0.8,
                                   label = NULL, chunk = "auto") {
    started <- Sys.time()
    check_min_coverage(min_coverage)
    survey_meta <- c4e_meta(survey) %||% empty_meta()
    x_meta <- c4e_meta(x) %||% empty_meta()
    if (is.null(window)) {
        if (is.null(interval)) {
            cli::cli_abort("Give {.arg interval} (e.g. {.val 1 year}) or a {.arg window}.")
        }
        window <- window_lag(interval, n_lags)
    } else if (!inherits(window, "c4e_window")) {
        cli::cli_abort("{.arg window} must come from {.fn window_lag} or a sibling.")
    }
    if (!is.null(label)) {
        c4e_progress_step("Summarising {label}")
    }

    by <- by %||% x_meta$key %||% resolve_key(x)
    if (!by %in% names(survey)) {
        cli::cli_abort("The survey has no {.field {by}} column linking it to {.arg x}.")
    }
    id_quo <- rlang::enquo(id)
    id_name <- if (rlang::quo_is_null(id_quo)) survey_meta$survey$id else rlang::as_name(id_quo)
    if (is.null(id_name)) {
        cli::cli_abort("Give {.arg id}, the column identifying the survey units.")
    }
    interview_quo <- rlang::enquo(interview)
    if (rlang::quo_is_null(interview_quo)) {
        if (is.null(survey_meta$survey$interview)) {
            cli::cli_abort("Give {.arg interview}, the interview dates.")
        }
        interview_quo <- rlang::quo(.data[[!!survey_meta$survey$interview]])
    }
    extra_names <- names(dplyr::select(tibble::as_tibble(survey), {{ extra_col }}))

    long <- if (identical(x_meta$shape, "wide")) to_long(x) else x
    long_meta <- c4e_meta(long) %||% x_meta
    date_col <- long_meta$date_col %||% "date"
    plans <- summary_plans(long, long_meta, stats)
    step <- long_meta$time_step %||% infer_time_step(parse_date_label(long[[date_col]]))

    keys <- tibble::as_tibble(survey) |>
        dplyr::transmute(.id = .data[[id_name]],
                         .by_key = .data[[by]],
                         .interview = parse_date_label(!!interview_quo),
                         dplyr::across(dplyr::all_of(extra_names)))
    if (identical(window$type, "since")) {
        keys$.event <- parse_date_label(tibble::as_tibble(survey)[[window$event]])
    }
    dropped <- is.na(keys$.interview)
    if (any(dropped)) {
        n_dropped <- sum(dropped)
        c4e_inform("{n_dropped} survey unit{?s} {?has/have} no interview date and
                    {?is/are} left out.")
        keys <- keys[!dropped, , drop = FALSE]
    }
    keys[[by]] <- keys$.by_key

    values <- tibble::as_tibble(long)[c(by, date_col, names(plans), intersect("value", names(long)))]
    names(values)[names(values) == date_col] <- "date"
    values$date <- parse_date_label(values$date)

    compute <- function(parts) {
        summarise_windows(parts$keys, parts$values, window, by, plans, step,
                          min_coverage, id_name, extra_names)
    }
    windows_all <- window_frame(window, keys[intersect(c(".by_key", ".interview", ".event"),
                                                       names(keys))])
    n_rows <- sum(expected_count(windows_all$w_start, windows_all$w_end, step))
    out <- with_chunks(list(keys = keys, values = values), compute, by = by,
                       chunk = chunk, label = "Window summaries",
                       what = "locations",
                       mem_estimate = estimate_bytes(n_rows, length(plans) + 4),
                       detail = paste(nrow(windows_all), "windows"))

    out <- out[do.call(order, c(unname(as.list(out[c(id_name, "lag")])),
                                method = "radix")), , drop = FALSE]
    entries <- summary_entries(plans, long_meta, window)
    meta <- modify_meta(empty_meta(), list(
        key = id_name, unit_cols = "lag", shape = "summary",
        variable = long_meta$variable, unit = long_meta$unit,
        time_step = long_meta$time_step, crs = long_meta$crs,
        source = long_meta$source, label = long_meta$label,
        window = c(list(type = window$type), window[setdiff(names(window), "type")],
                   list(interview = survey_meta$survey$interview)),
        survey = survey_meta$survey,
        survey_cols = if (length(extra_names) > 0) extra_names,
        indicators = entries[intersect(names(entries), names(out))],
        history = unique(c(survey_meta$history, long_meta$history))
    ))
    args <- if (window$type == "lag" && !is.null(interval)) {
        list(interval = interval, n_lags = n_lags)
    } else {
        list(window = unclass(window))
    }
    meta <- c4e_record(meta, "summarise_by_interview",
                       c(args, list(min_coverage = min_coverage)), started)
    new_c4e_tbl(out, prune_meta(meta, names(out)))
}

#' The summaries of one chunk of locations
#' @noRd
summarise_windows <- function(keys, values, window, by, plans, step,
                              min_coverage, id_name, extra_names) {
    key_cols <- intersect(c(".by_key", ".interview", ".event"), names(keys))
    windows <- window_frame(window, keys[key_cols])
    group <- c(key_cols, "lag")

    present_col <- if ("value" %in% names(values)) "value" else names(plans)[1]
    joined <- values |>
        dplyr::rename(.by_key = dplyr::all_of(by)) |>
        dplyr::inner_join(windows,
                          by = dplyr::join_by(".by_key", date > w_start, date <= w_end))

    summaries <- joined |>
        dplyr::summarise(
            .present = sum(!is.na(.data[[present_col]])),
            !!!summary_expressions(plans),
            .by = dplyr::all_of(group))

    summaries <- dplyr::left_join(windows, summaries, by = group) |>
        dplyr::mutate(.expected = expected_count(.data$w_start, .data$w_end, step))
    short <- is.na(summaries$.present) |
        summaries$.present < min_coverage * summaries$.expected
    stat_cols <- setdiff(names(summaries), c(names(windows), ".present", ".expected"))
    summaries[short, stat_cols] <- NA

    keys |>
        dplyr::select(dplyr::all_of(c(".id", key_cols, extra_names))) |>
        dplyr::inner_join(summaries[c(group, stat_cols)], by = key_cols,
                          relationship = "many-to-many") |>
        dplyr::select(dplyr::all_of(c(".id", "lag", extra_names, stat_cols))) |>
        dplyr::rename(!!id_name := ".id")
}

#' Which statistics to compute for which column
#' @noRd
summary_plans <- function(long, meta, stats, call = rlang::caller_env()) {
    defaults <- list(flag = "sum", excess = "sum", spell = c("max", "mean", "sum", "n"),
                     std = "mean")
    if (!is.null(stats)) {
        if (!is.list(stats) || !rlang::is_named(stats)) {
            cli::cli_abort("{.arg stats} must be a named list by kind, e.g.
                            {.code list(flag = \"sum\")}.", call = call)
        }
        defaults[names(stats)] <- stats
    }
    known <- c("sum", "mean", "max", "min", "n")
    unknown <- setdiff(unlist(defaults), known)
    if (length(unknown) > 0) {
        cli::cli_abort("Unknown statistic{?s} {.val {unknown}}; use {.or {.val {known}}}.",
                       call = call)
    }

    registered <- purrr::keep(meta$indicators, \(entry) entry$kind %in% names(defaults))
    registered <- registered[intersect(names(registered), names(long))]
    if (length(registered) > 0) {
        return(lapply(registered, \(entry) defaults[[entry$kind]]))
    }
    # tables without a registry: the v1 column names
    plans <- list()
    for (col in names(long)) {
        if (grepl("^day", col) || (grepl("abv|blw", col) && !grepl("^spell", col))) {
            plans[[col]] <- defaults$flag
        } else if (grepl("^spell", col)) {
            plans[[col]] <- defaults$spell
        }
    }
    if (length(plans) == 0) {
        cli::cli_abort("{.arg x} has no indicator columns to summarise.", call = call)
    }
    plans
}

#' dplyr summarise expressions, named <column>_<stat>, with v1's NA rules
#' @noRd
summary_expressions <- function(plans) {
    exprs <- list()
    for (col in names(plans)) {
        for (stat in plans[[col]]) {
            value <- rlang::expr(.data[[!!col]])
            exprs[[paste0(col, "_", stat)]] <- switch(
                stat,
                sum  = rlang::expr(sum_na_check(!!value)),
                mean = rlang::expr(mean_na_check(!!value)),
                max  = rlang::expr(max_na_check(!!value)),
                min  = rlang::expr(min_na_check(!!value)),
                n    = rlang::expr(sum(!is.na(!!value)))
            )
        }
    }
    exprs
}

#' Minimum, 0 when every value is missing (like max_na_check)
#' @noRd
min_na_check <- function(x, replace = 0) {
    if (all(is.na(x))) replace else min(x, na.rm = TRUE)
}

#' Registry entries of the summary columns, carrying their source's details
#' @noRd
summary_entries <- function(plans, meta, window) {
    entries <- list()
    for (col in names(plans)) {
        source <- meta$indicators[[col]] %||% list()
        for (stat in plans[[col]]) {
            entries[[paste0(col, "_", stat)]] <- new_indicator(
                "agg", base = col, stat = stat, direction = source$direction,
                threshold = source$threshold, p = source$p,
                min_spell = source$min_spell, index = source$index,
                scale = source$scale, condition = source$condition,
                unit = source$unit, variable = source$variable,
                of = source$kind, definition = source$definition,
                step = source$step, window = window$type)
        }
    }
    entries
}

check_min_coverage <- function(min_coverage, call = rlang::caller_env()) {
    if (!is.numeric(min_coverage) || length(min_coverage) != 1 ||
        is.na(min_coverage) || min_coverage < 0 || min_coverage > 1) {
        cli::cli_abort("{.arg min_coverage} must be a single number between 0 and 1.",
                       call = call)
    }
}

#' Summarise indicators by calendar period
#'
#' Summarises the indicators of each unit by month or year, for panels and
#' maps without a survey: hot days per month, the longest spell per year.
#' The statistics follow the registry as in [summarise_by_interview()], and a
#' period with less than `min_coverage` of its days present gives `NA`.
#'
#' @param x A long indicator table.
#' @param period `"month"` or `"year"`.
#' @inheritParams summarise_by_interview
#'
#' @return A long `c4e_tbl` with the unit identifiers, `period` (the date the
#'   period starts) and one column per indicator and statistic, with the new
#'   time step.
#'
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:59,
#'                  value = rep(c(28, 31, 33), 20)),
#'   key = "ID", date_col = "date", shape = "long", unit = "C", time_step = "day")
#' calc_threshold_day(x, above = 30) |>
#'   summarise_by_period("month", min_coverage = 0)
summarise_by_period <- function(x, period = c("month", "year"), stats = NULL,
                                min_coverage = 0.8, id = NULL, label = NULL) {
    started <- Sys.time()
    period <- rlang::arg_match(period)
    check_min_coverage(min_coverage)
    frame <- indicator_frame(x, id)
    meta <- frame$meta
    plans <- summary_plans(tibble::as_tibble(frame$data), meta, stats)
    step <- meta$time_step %||% infer_time_step(frame$dates)

    data <- tibble::as_tibble(frame$data)
    data$period <- lubridate::floor_date(parse_date_label(data[[frame$date_col]]), period)
    present_col <- if ("value" %in% names(data)) "value" else names(plans)[1]
    out <- data |>
        dplyr::summarise(.present = sum(!is.na(.data[[present_col]])),
                         !!!summary_expressions(plans),
                         .by = dplyr::all_of(c(frame$id_cols, "period")))
    period_end <- lubridate::ceiling_date(out$period, period, change_on_boundary = TRUE) - 1L
    expected <- expected_count(out$period - 1L, period_end, step)
    stat_cols <- setdiff(names(out), c(frame$id_cols, "period", ".present"))
    out[out$.present < min_coverage * expected, stat_cols] <- NA
    out$.present <- NULL
    out <- sort_long(out, c(frame$id_cols, "period"))

    entries <- summary_entries(plans, meta, list(type = "period"))
    entries <- lapply(entries, \(entry) {
        entry$period <- period
        entry$window <- NULL
        entry
    })
    new_meta <- modify_meta(meta, list(
        shape = "long", date_col = "period", time_step = period,
        indicators = entries))
    new_meta <- c4e_record(new_meta, "summarise_by_period",
                           list(period = period, min_coverage = min_coverage), started)
    new_c4e_tbl(out, prune_meta(new_meta, names(out)))
}
