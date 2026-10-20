#' Aggregate a raster to a coarser time step
#'
#' Aggregates the layers of a raster by day, month or year, for example
#' hourly ERA5 temperature to daily maxima or daily rainfall to monthly
#' totals. The result's layers are named by the ISO date on which each period
#' starts (`"2021-02-01"` for February 2021), carry those dates, and record
#' the new time step.
#'
#' When `fn` is not given it follows from the variable: amounts such as
#' precipitation and evapotranspiration are summed, categorical layers take
#' the most frequent value, everything else is averaged. The choice is
#' announced. Summing a rate per time step gives a rate per new period, so
#' daily `"mm/day"` summed to months is recorded as `"mm/month"`.
#'
#' @param x A `SpatRaster` with dates, ideally read with [read_climate()].
#' @param to Target time step: `"day"`, `"month"` or `"year"`.
#' @param fn Summary function name passed to [terra::tapp()], e.g. `"sum"`,
#'   `"mean"`, `"max"`, `"min"`, `"modal"`.
#' @param ... Further arguments to [terra::tapp()], e.g. `na.rm = TRUE`.
#' @param label Optional label for the result; defaults to that of `x`.
#'
#' @return A `SpatRaster` with one layer per period.
#'
#' @seealso [read_climate()], [raster_meta()]
#' @export
#'
#' @examples
#' pre <- read_climate(
#'   system.file("extdata", "pre_daily.tif", package = "c4e"))
#' monthly <- aggregate_time(pre[[1:59]], "month")
#' names(monthly)
aggregate_time <- function(x, to = c("day", "month", "year"), fn = NULL, ...,
                           label = NULL) {
    if (!inherits(x, "SpatRaster")) {
        cli::cli_abort("{.arg x} must be a {.cls SpatRaster}.")
    }
    to <- rlang::arg_match(to)
    if (!terra::has.time(x) || all(is.na(terra::time(x)))) {
        cli::cli_abort(c(
            "{.arg x} has no dates to aggregate by.",
            "i" = "Read it with {.fn read_climate}, or set {.code terra::time(x)}."
        ))
    }
    stored <- stored_raster_meta(x)
    meta   <- raster_meta(x)
    steps  <- c("hour", "day", "month", "year")
    if (!is.null(meta$time_step) &&
        match(to, steps) <= match(meta$time_step, steps)) {
        from_step <- meta$time_step
        cli::cli_abort(
            "{.arg to} must be coarser than the data's time step: {.val {to}} is
             not coarser than {.val {from_step}}.")
    }

    if (is.null(fn)) {
        choice <- default_time_fn(meta$variable, meta$kind)
        fn <- choice$fn
        reason <- choice$reason
        c4e_inform("Aggregating to {to} with {.code fn = \"{fn}\"}: {reason}.")
    }
    if (!rlang::is_string(fn)) {
        cli::cli_abort("{.arg fn} must be the name of a summary function, such as
                        {.val sum} or {.val mean}.")
    }

    dates <- terra::time(x)
    if (is.unsorted(dates)) {
        sorted <- order(dates)
        x <- keep_raster_meta(x[[sorted]], x)
        dates <- dates[sorted]
    }
    day_dates <- as.Date(format(dates, "%Y-%m-%d"))
    starts <- format(lubridate::floor_date(day_dates, unit = to), "%Y-%m-%d")
    periods <- unique(starts)

    out <- terra::tapp(x, index = starts, fun = fn, ...)
    names(out) <- periods
    terra::time(out) <- as.Date(periods)

    unit <- canonical_unit(raster_unit(x))
    if (!is.null(unit) && identical(fn, "sum")) {
        unit <- summed_unit(unit, meta$time_step, to)
    }
    if (!is.null(unit)) {
        terra::units(out) <- unit
    }
    stored$time_step <- to
    stored$label <- label %||% stored$label
    set_raster_meta(out, stored)
}

#' The summary that fits the variable, and why
#' @noRd
default_time_fn <- function(variable, kind) {
    name <- variable %||% "the variable"
    if (identical(kind, "categorical")) {
        return(list(fn = "modal", reason = paste(name, "is categorical")))
    }
    if (identical(kind, "count")) {
        return(list(fn = "sum", reason = paste(name, "is a count")))
    }
    if (isTRUE(variable %in% amount_variables)) {
        return(list(fn = "sum", reason = paste(name, "is an amount")))
    }
    list(fn = "mean", reason = paste(name, "is a level"))
}

#' Unit of a sum over periods: a rate per step becomes a rate per period
#' @noRd
summed_unit <- function(unit, step, to) {
    rate <- split_rate(unit)
    if (is.null(rate$per)) {
        return(unit)
    }
    if (identical(rate$per, step)) {
        return(paste0(rate$base, "/", to))
    }
    cli::cli_warn(c(
        "Summing values in {.val {unit}} recorded every {step %||% 'step'}
         does not give a total per {to}.",
        "i" = "Convert the unit first, e.g. to a rate per {step %||% 'step'},
               with {.fn convert_unit}."
    ))
    unit
}
