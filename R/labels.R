# Human-readable labels for the columns of a c4e table (plan §6), used by
# write_stata(), the codebook and summary(). Labels are built from the
# registry when needed, never stored, so they cannot go out of date.

#' Labels describing the columns of a table
#'
#' Builds one label per column from the context the table carries: what each
#' indicator counts, its threshold and unit, its spell length, the window it
#' was summarised over. For example `day_abv_30_sum` becomes "sum of days
#' above 30 C, 1 year before the interview". [write_stata()] writes them as
#' Stata variable labels.
#'
#' @param x A `c4e_tbl`.
#'
#' @return A named character vector, one label per described column, at most
#'   80 characters (Stata's limit).
#'
#' @seealso [write_stata()]
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
#'                  value = c(28, 31, 33, 29, 31)),
#'   key = "ID", date_col = "date", shape = "long", variable = "tmax",
#'   unit = "C", time_step = "day")
#' calc_threshold_day(x, above = 30) |> c4e_labels()
c4e_labels <- function(x) {
    meta <- c4e_meta(x) %||% empty_meta()
    labels <- character()
    for (col in intersect(names(meta$indicators), names(x))) {
        labels[[col]] <- indicator_label(meta$indicators[[col]], meta)
    }
    if ("value" %in% names(x) && !is.null(meta$variable)) {
        labels[["value"]] <- series_label(meta)
    }
    if ("lag" %in% names(x) && !is.null(meta$window)) {
        labels[["lag"]] <- paste0("periods before the interview (",
                                  describe_window(meta$window), ")")
    }
    vapply(labels, truncate_label, character(1))
}

truncate_label <- function(label, width = 80) {
    if (nchar(label) <= width) label else paste0(substr(label, 1, width - 3), "...")
}

#' "tmax in C, daily"
#' @noRd
series_label <- function(meta) {
    step <- switch(meta$time_step %||% "none", hour = "hourly", day = "daily",
                   month = "monthly", year = "yearly", NULL)
    paste(c(paste0(meta$variable, if (!is.null(meta$unit)) paste(" in", meta$unit)),
            step), collapse = ", ")
}

#' The label of one registry entry
#'
#' @param entry A registry entry.
#' @param meta The table's metadata, for the step, unit and window.
#' @noRd
indicator_label <- function(entry, meta) {
    steps <- step_word(entry$step %||% meta$time_step)
    switch(entry$kind,
           flag   = flag_label(entry, steps),
           excess = excess_label(entry, meta),
           spell  = spell_label(entry, steps),
           pct    = pct_label(entry, meta),
           std    = paste0(toupper(entry$index %||% "index"), " over ",
                           entry$scale, " month", if (isTRUE(entry$scale > 1)) "s"),
           par    = par_label(entry, meta),
           agg    = agg_label(entry, meta),
           entry$kind)
}

step_word <- function(step) {
    switch(step %||% "day", hour = "hours", day = "days", month = "months",
           year = "years", "days")
}

ordinal <- function(n) {
    n <- format(n, trim = TRUE)
    last <- substring(n, nchar(n))
    two <- if (nchar(n) >= 2) substring(n, nchar(n) - 1) else n
    suffix <- if (two %in% c("11", "12", "13")) "th" else
        switch(last, "1" = "st", "2" = "nd", "3" = "rd", "th")
    paste0(n, suffix)
}

#' "above 30 C", "below the 10th percentile", "above the 90th percentile of the year"
#' @noRd
threshold_phrase <- function(entry) {
    if (is.character(entry$threshold)) {
        p <- entry$p %||% percentile_p(entry$threshold)
        year <- if (grepl("^yr_", entry$threshold)) " of the year" else ""
        return(paste0(entry$direction, " the ", ordinal(p * 100), " percentile", year))
    }
    paste(c(entry$direction, entry$threshold, entry$unit), collapse = " ")
}

flag_label <- function(entry, steps) {
    if (!is.null(entry$condition)) {
        return(paste0(steps, " with ", entry$condition))
    }
    if (!is.null(entry$index)) {
        return(paste0(steps, " with ", toupper(entry$index), "-", entry$scale, " ",
                      entry$direction, " ", entry$threshold))
    }
    paste(steps, threshold_phrase(entry))
}

excess_label <- function(entry, meta) {
    if (identical(entry$unit, paste0(meta$time_step %||% "day", "s")) ||
        grepl("^spell", entry$base %||% "")) {
        return(paste0("days of spell beyond the ",
                      ordinal((entry$p %||% percentile_p(entry$threshold)) * 100),
                      " percentile"))
    }
    paste0("excess ", threshold_phrase(entry),
           if (is.character(entry$threshold) && !is.null(entry$unit)) paste0(", in ", entry$unit))
}

spell_label <- function(entry, steps) {
    if (identical(entry$definition, "wmo")) {
        return(paste0("heatwave length (WMO, ", entry$threshold, " above monthly mean, ",
                      entry$min_spell, "+ ", steps, ")"))
    }
    paste("spell length", spell_core(entry, steps))
}

#' "above 30 C (2+ days)", the part shared by every spell label
#' @noRd
spell_core <- function(entry, steps) {
    what <- if (!is.null(entry$condition)) {
        paste("with", entry$condition)
    } else if (!is.null(entry$index)) {
        paste0("with ", toupper(entry$index), "-", entry$scale, " ", entry$direction,
               " ", entry$threshold)
    } else {
        threshold_phrase(entry)
    }
    paste0(what, " (", entry$min_spell, "+ ", steps, ")")
}

pct_label <- function(entry, meta) {
    what <- if (grepl("^spell", entry$base %||% "")) {
        paste("spell length", threshold_phrase(entry))
    } else {
        series_label(list(variable = entry$variable %||% meta$variable %||% "value",
                          unit = entry$unit %||% meta$unit,
                          time_step = meta$time_step))
    }
    period <- if (identical(entry$period, "year")) "over the year" else "by month"
    paste0(ordinal(entry$p * 100), " percentile of ", what, ", ", period)
}

par_label <- function(entry, meta) {
    period <- switch(entry$period %||% "all", all = "all observations",
                     year = "averaged over years", month = "averaged over months")
    paste0(entry$stat, " of ", entry$variable %||% meta$variable %||% "value",
           if (!is.null(entry$unit %||% meta$unit)) paste0(" (", entry$unit %||% meta$unit, ")"),
           ", ", period)
}

agg_label <- function(entry, meta) {
    source <- entry
    source$kind <- entry$of %||% "flag"
    steps <- step_word(entry$step %||% meta$time_step)
    base <- indicator_label(source, meta)
    stat <- entry$stat
    text <- switch(source$kind,
        flag = switch(stat, sum = base, mean = paste("share of", base),
                      paste(stat, "of", base)),
        excess = switch(stat, sum = paste("total", base), paste(stat, base)),
        spell = if (identical(source$definition, "wmo")) {
            paste(stat, "of", base)
        } else {
            core <- spell_core(source, steps)
            switch(stat,
                   max  = paste("longest spell", core),
                   min  = paste("shortest spell", core),
                   mean = paste("mean spell length", core),
                   sum  = paste("total spell", steps, core),
                   n    = paste("number of spells", core),
                   paste(stat, "of", base))
        },
        paste(stat, "of", base))
    window <- if (!is.null(meta$window)) paste0(", ", window_phrase(meta$window)) else ""
    paste0(text, window)
}

#' "per 1-year window", "per Jun-Sep season", the short form for labels
#' @noRd
window_phrase <- function(window) {
    switch(window$type,
           lag    = paste0("per ", sub(" ", "-", sub("s$", "", window$interval)), " window"),
           season = paste0("per ", month.abb[window$start_month], "-",
                           month.abb[window$end_month], " season"),
           fixed  = paste0("from ", window$from, " to ", window$to),
           since  = paste0("since ", window$event),
           describe_window(window))
}
