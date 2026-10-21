#' Percentiles of daily values by unit and month
#'
#' Computes, for each unit and calendar month, percentiles of the daily
#' values over all years of the baseline, e.g. the 90th percentile of
#' maximum temperature in July. These are the relative thresholds that
#' [calc_percentile_day()] compares each day with. Replaces
#' `calc_pct_day()`.
#'
#' Use `exclude_below` to leave out values, for instance days with less than
#' 0.1 mm of rain, so the percentiles describe wet days only. A unit and
#' month left with no value gets `replace` (by default `NA`, so no day is
#' flagged against it).
#'
#' @param x A wide table from `extract_*()`, or a long indicator table.
#' @param p Probabilities, e.g. `c(0.1, 0.9)`.
#' @param exclude_below,exclude_above Values beyond these are left out.
#' @param yearly When `TRUE`, also compute percentiles over all days of the
#'   year (columns `yr_90p`), repeated on every month.
#' @param baseline Optional dates `c(from, to)` limiting the days used, e.g.
#'   `c("1991-01-01", "2020-12-31")`.
#' @param replace Value for a unit and month with no data.
#' @inheritParams calc_threshold_day
#'
#' @return A `c4e_tbl` lookup table: the unit identifiers, `month` (`"01"` to
#'   `"12"`) and one column per percentile (`day_90p`), registered with their
#'   probability and baseline.
#'
#' @seealso [calc_percentile_day()], [calc_spell_percentile()]
#' @family indicators
#' @param ... Further arguments of the methods; the table method takes
#'   none.
#' @export
#'
#' @examples
#' pre <- read_climate(
#'   system.file("extdata", "pre_daily.tif", package = "c4e"))
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' extract_by_coord(pre, points) |>
#'   calc_percentile(p = c(0.9, 0.99), exclude_below = 0.1)
calc_percentile <- function(x, ...) {
    UseMethod("calc_percentile")
}

#' @rdname calc_percentile
#' @export
calc_percentile.default <- function(x, p, exclude_below = NULL, exclude_above = NULL,
                                    yearly = FALSE, baseline = NULL, replace = NA_real_,
                                    id = NULL, label = NULL, chunk = "auto", ...) {
    rlang::check_dots_empty()
    started <- Sys.time()
    if (!is.numeric(p) || any(p < 0 | p > 1)) {
        cli::cli_abort("{.arg p} must be probabilities between 0 and 1.")
    }

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        values <- frame_matrix(frame, "value")
        dates <- frame$dates
        if (!is.null(baseline)) {
            keep <- dates_between(dates, baseline[1], baseline[2])
            values <- values[, keep, drop = FALSE]
            dates <- dates[keep]
        }
        monthly <- quantile_by_month(values, dates, p, exclude_below,
                                     exclude_above, replace)
        months <- colnames(monthly[[1]])
        prefix <- step_prefix(frame$meta$time_step)

        out <- frame$ids[rep(seq_len(nrow(frame$ids)), each = length(months)), ,
                         drop = FALSE]
        out$month <- rep(months, times = nrow(frame$ids))
        entries <- list()
        common <- list(base = "value", exclude_below = exclude_below,
                       exclude_above = exclude_above,
                       variable = frame$meta$variable, unit = frame$meta$unit)
        for (j in seq_along(p)) {
            col <- paste0(prefix, "_", names(monthly)[j])
            out[[col]] <- as.vector(t(monthly[[j]]))
            entries[[col]] <- do.call(new_indicator,
                                      c(list("pct", p = p[j], period = "month"), common))
        }
        if (yearly) {
            filtered <- values
            if (!is.null(exclude_below)) filtered[!is.na(filtered) & filtered < exclude_below] <- NA
            if (!is.null(exclude_above)) filtered[!is.na(filtered) & filtered > exclude_above] <- NA
            whole_year <- row_quantiles(filtered, p, replace)
            for (j in seq_along(p)) {
                col <- paste0("yr_", names(monthly)[j])
                out[[col]] <- rep(whole_year[, j], each = length(months))
                entries[[col]] <- do.call(new_indicator,
                                          c(list("pct", p = p[j], period = "year"), common))
            }
        }

        meta <- modify_meta(frame$meta, list(
            shape = "lookup", date_col = NULL,
            date_range = if (length(dates) > 0) range(dates),
            indicators = entries
        ))
        new_c4e_tbl(out, prune_meta(meta, names(out)))
    }

    run_indicator(x, compute, "calc_percentile",
                  args = list(p = p, exclude_below = exclude_below,
                              exclude_above = exclude_above,
                              yearly = if (yearly) TRUE, baseline = baseline),
                  n_new = length(p) * (1 + yearly), id = id, label = label,
                  chunk = chunk, started = started)
}

#' Flag days beyond their unit's monthly percentiles
#'
#' Compares each day with the percentile of its unit and calendar month from
#' [calc_percentile()]: a day above the 90th percentile of July is flagged
#' `day_abv_90p`, and its distance above goes in `<unit>_abv_90p`. Replaces
#' `find_extr_rel_day()`.
#'
#' Whether a percentile is an upper or a lower threshold follows from its
#' probability (0.5 and above are upper), unless `tail` says otherwise; the
#' choice is announced. The percentiles must describe the same variable, in
#' the same unit, as `x`.
#'
#' @param x A wide table from `extract_*()`, or a long indicator table.
#' @param pct A percentile table from [calc_percentile()].
#' @param tail `NULL` to decide per column, or `"upper"` / `"lower"` for all.
#' @inheritParams calc_threshold_day
#'
#' @return A long `c4e_tbl` with flag and excess columns per percentile.
#'
#' @family indicators
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' tmax_points <- extract_by_coord(tmax, points)
#' pct <- calc_percentile(tmax_points, p = c(0.1, 0.9))
#' calc_percentile_day(tmax_points, pct)
calc_percentile_day <- function(x, pct, tail = NULL, unit = NULL, id = NULL,
                                label = NULL, chunk = "auto") {
    started <- Sys.time()
    if (!is.data.frame(pct)) {
        cli::cli_abort("{.arg pct} must be a table of percentiles from
                        {.fn calc_percentile}.")
    }
    meta <- c4e_meta(x) %||% empty_meta()
    pct_meta <- c4e_meta(pct) %||% empty_meta()
    check_meta_agrees(pct_meta$variable, meta$variable, "variable",
                      hint = "The percentiles were computed from another variable.")
    check_meta_agrees(canonical_unit(pct_meta$unit), canonical_unit(meta$unit),
                      "unit", hint = "Convert one of the two with {.fn convert_unit}.")
    unit <- resolve_unit(unit, meta)
    if (!is.null(tail)) {
        tail <- rlang::arg_match(tail, c("upper", "lower"))
    }

    columns <- percentile_columns(pct)
    directions <- vapply(columns, \(col) {
        if (!is.null(tail)) return(if (tail == "upper") "above" else "below")
        if (percentile_p(col, pct_meta$indicators[[col]]) >= 0.5) "above" else "below"
    }, character(1))
    if (is.null(tail)) {
        upper <- columns[directions == "above"]
        lower <- columns[directions == "below"]
        message <- c("i" = "Percentiles of 0.5 and above are upper thresholds,
                            the others lower.")
        if (length(upper) > 0) {
            message <- c(message, " " = "Flagging above: {.field {upper}}.")
        }
        if (length(lower) > 0) {
            message <- c(message, " " = "Flagging below: {.field {lower}}.")
        }
        c4e_inform(message)
    }
    # identifiers, month and the chosen percentile columns only
    id_like <- unique(c(pct_meta$key, pct_meta$unit_cols, "month",
                        names(pct)[!vapply(pct, is.numeric, logical(1))]))
    table <- tibble::as_tibble(pct)[intersect(c(id_like, columns), names(pct))]
    table <- new_c4e_tbl(table, prune_meta(pct_meta, names(table)))

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        values <- frame_matrix(frame, "value")
        built <- table_thresholds(frame, values, table,
                                  direction = \(col, entry) directions[[col]],
                                  unit = unit)
        finish_frame(frame, built$columns, built$entries,
                     list(unit = canonical_unit(unit) %||% frame$meta$unit))
    }

    run_indicator(x, compute, "calc_percentile_day",
                  args = list(tail = tail, unit = unit),
                  n_new = 2 * length(columns), id = id, label = label,
                  chunk = chunk, started = started)
}

#' Percentile columns of a table: from the registry, else by their v1 names
#' @noRd
percentile_columns <- function(pct) {
    meta <- c4e_meta(pct) %||% empty_meta()
    registered <- names(purrr::keep(meta$indicators, \(entry) identical(entry$kind, "pct")))
    registered <- intersect(registered, names(pct))
    if (length(registered) > 0) {
        return(registered)
    }
    found <- grep("^[a-z]{1,3}_[0-9.]+p$", names(pct), value = TRUE)
    if (length(found) == 0) {
        cli::cli_abort("{.arg pct} has no percentile column such as {.field day_90p}.",
                       call = rlang::caller_env(2))
    }
    found
}

#' The probability of a percentile column
#' @noRd
percentile_p <- function(col, entry = NULL) {
    entry$p %||% (as.numeric(sub(".*_([0-9.]+)p$", "\\1", col)) / 100)
}
