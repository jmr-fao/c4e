# Named specifications for the wrappers (plan §12): a word instead of five
# numbers. Any argument given explicitly overrides the preset.

c4e_presets <- function() {
    list(
        heavy_rain = list(
            wrapper = "weather_extremes", variable = "pre", unit = "mm/day",
            time_step = "day", above = c(20, 50),
            description = "days with at least 20 and 50 mm of rain"),
        wet_days_p95 = list(
            wrapper = "weather_extremes", variable = "pre", unit = "mm/day",
            time_step = "day", p = c(0.95, 0.99), exclude_below = 0.1,
            description = "days above the 95th and 99th percentile of wet days"),
        dry_spell = list(
            wrapper = "weather_extremes", variable = "pre", unit = "mm/day",
            time_step = "day", below = 1, min_spell = 5,
            description = "spells of at least 5 days with less than 1 mm"),
        dry_days_p10 = list(
            wrapper = "weather_extremes", variable = "pre", unit = "mm/day",
            time_step = "day", p = 0.10, exclude_below = 0.1,
            description = "days below the 10th percentile of wet days"),
        heat = list(
            wrapper = "weather_extremes", variable = "tmax", unit = "C",
            time_step = "day", above = c(30, 35),
            description = "days with a maximum above 30 and 35 C"),
        heatwave_wmo = list(
            wrapper = "weather_extremes", variable = "tmax", unit = "C",
            time_step = "day", heatwave = list(excess = 5, min_spell = 2),
            description = "WMO heatwaves: 2+ days 5 C above the monthly mean"),
        hot_days_p90 = list(
            wrapper = "weather_extremes", variable = "tmax", unit = "C",
            time_step = "day", p = c(0.90, 0.95),
            description = "days above the 90th and 95th percentile of tmax"),
        cold = list(
            wrapper = "weather_extremes", variable = "tmin", unit = "C",
            time_step = "day", below = c(0, -5),
            description = "days with a minimum below 0 and -5 C"),
        cold_days_p10 = list(
            wrapper = "weather_extremes", variable = "tmin", unit = "C",
            time_step = "day", p = c(0.10, 0.05),
            description = "days below the 10th and 5th percentile of tmin"),
        drought_spi3 = list(
            wrapper = "climate_indices", variable = "pre", time_step = "month",
            index = "spi", scale = 3, below = c(-1, -1.5, -2),
            description = "months of moderate, severe and extreme 3-month drought")
    )
}

#' List the presets of the wrappers
#'
#' Presets fill the thresholds, percentiles and spell length of
#' [weather_extremes()] and [climate_indices()] with common definitions, so
#' a single word replaces several numbers. Arguments given explicitly
#' override the preset. A preset checks that the data are the variable and
#' time step it expects, and converts the unit when needed.
#'
#' @return A tibble with one row per preset: its name, the wrapper it
#'   belongs to, the variable, unit and time step it expects, its
#'   specification and a description.
#'
#' @seealso [weather_extremes()], [climate_indices()]
#' @export
#'
#' @examples
#' list_presets()
list_presets <- function() {
    presets <- c4e_presets()
    spec_text <- function(preset) {
        parts <- c(
            if (!is.null(preset$above)) paste0("above = ", format_value(preset$above)),
            if (!is.null(preset$below)) paste0("below = ", format_value(preset$below)),
            if (!is.null(preset$p)) paste0("p = ", format_value(preset$p)),
            if (!is.null(preset$exclude_below)) paste0("exclude_below = ", preset$exclude_below),
            if (!is.null(preset$min_spell)) paste0("min_spell = ", preset$min_spell),
            if (!is.null(preset$heatwave)) paste0("heatwave excess = ", preset$heatwave$excess),
            if (!is.null(preset$index)) paste0(preset$index, " scale = ", preset$scale)
        )
        paste(parts, collapse = ", ")
    }
    tibble::tibble(
        preset      = names(presets),
        wrapper     = vapply(presets, `[[`, "", "wrapper"),
        variable    = vapply(presets, `[[`, "", "variable"),
        unit        = vapply(presets, \(x) x$unit %||% NA_character_, character(1)),
        time_step   = vapply(presets, `[[`, "", "time_step"),
        spec        = vapply(presets, spec_text, character(1)),
        description = vapply(presets, `[[`, "", "description")
    )
}

#' The specification of a preset, checked against the wrapper
#' @noRd
preset_spec <- function(preset, wrapper, call = rlang::caller_env()) {
    if (is.null(preset)) {
        return(list())
    }
    presets <- c4e_presets()
    if (!rlang::is_string(preset) || !preset %in% names(presets)) {
        cli::cli_abort(c("Unknown preset {.val {preset}}.",
                         "i" = "See {.fn list_presets} for the presets."),
                       call = call)
    }
    spec <- presets[[preset]]
    if (!identical(spec$wrapper, wrapper)) {
        right <- spec$wrapper
        cli::cli_abort("{.val {preset}} is a preset of {.fn {right}}.", call = call)
    }
    spec
}

#' Refuse data that are not what the preset describes
#' @noRd
check_preset_data <- function(spec, meta, preset, call = rlang::caller_env()) {
    if (is.null(preset)) {
        return(invisible(TRUE))
    }
    expected <- paste(c(switch(spec$time_step, day = "daily", month = "monthly",
                               spec$time_step),
                        spec$variable, if (!is.null(spec$unit)) paste("in", spec$unit)),
                      collapse = " ")
    found <- paste(c(switch(meta$time_step %||% "unknown", day = "daily",
                            month = "monthly", meta$time_step %||% "undated"),
                     meta$variable %||% "an unknown variable",
                     if (!is.null(meta$unit)) paste("in", meta$unit)),
                   collapse = " ")
    variable_ok <- identical(meta$variable, spec$variable)
    step_ok <- identical(meta$time_step, spec$time_step) ||
        (identical(spec$time_step, "month") && identical(meta$time_step, "day"))
    if (!variable_ok || !step_ok) {
        variable <- spec$variable
        cli::cli_abort(c(
            "{.val {preset}} expects {expected}; the data are {found}.",
            "i" = "If the data are {variable}, declare it with
                   {.code read_climate(path, variable = \"{variable}\")}; otherwise
                   choose another preset from {.fn list_presets}."
        ), call = call)
    }
    invisible(TRUE)
}

# ==== Control lists ======================================================== ----

#' Further options of the wrappers
#'
#' The wrappers keep their signatures short; the less common options go in a
#' control list, in the style of `stats::glm.control()`.
#'
#' @param exclude_below Values left out of percentiles, e.g. `0.1` mm for wet
#'   days. For precipitation percentiles it defaults to 0.1.
#' @param yearly Also compute year-round percentiles.
#' @param spell_excess Also compute spell-length percentiles and the excess
#'   of each spell over them, when percentiles are used.
#' @param min_coverage Share of a window that must be covered by data.
#' @param fill_missing Fill missing cells from their neighbours before
#'   extracting.
#' @param keep_steps Return a list with every intermediate table instead of
#'   the final one.
#' @param dry_run Print the plan and the estimated sizes, and stop.
#' @param chunk Splitting of large steps, passed to the steps; see
#'   `?c4e`.
#' @param verbose `FALSE` silences messages and progress.
#' @param label Name shown in progress messages.
#' @param .parallel Fit SPI/SPEI series with `furrr`.
#'
#' @return A list of class `c4e_control`.
#'
#' @seealso [weather_extremes()], [climate_indices()], [static_controls()],
#'   [time_varying_controls()]
#' @export
#'
#' @examples
#' extremes_control(min_coverage = 1, keep_steps = TRUE)
extremes_control <- function(exclude_below = NULL, yearly = FALSE,
                             spell_excess = FALSE, min_coverage = 0.8,
                             fill_missing = FALSE, keep_steps = FALSE,
                             dry_run = FALSE, chunk = "auto", verbose = NULL,
                             label = NULL) {
    new_control(as.list(environment()))
}

#' @rdname extremes_control
#' @export
indices_control <- function(min_coverage = 0.8, fill_missing = FALSE,
                            keep_steps = FALSE, dry_run = FALSE, chunk = "auto",
                            verbose = NULL, label = NULL, .parallel = FALSE) {
    new_control(as.list(environment()))
}

#' @rdname extremes_control
#' @export
controls_control <- function(fill_missing = TRUE, keep_steps = FALSE,
                             dry_run = FALSE, verbose = NULL, label = NULL) {
    new_control(as.list(environment()))
}

new_control <- function(values) {
    structure(values, class = "c4e_control")
}
