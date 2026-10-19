# Units of measure: names, conversions, convert_unit() (plan §2, §11.7).
#
# A unit is either simple ("K", "mm", "kg/m2") or a rate per unit of time
# ("mm/day", "kg/m2/s", "m/s"). Simple units convert through a registry of
# factors and offsets (value_to = value_from * factor + offset), used in
# either direction. Rates convert their numerator through the same registry
# and their time denominator by its length in seconds; months and years have
# varying lengths, so those conversions need the dates of the data.

# ==== Registry ============================================================ ----

c4e_units <- new.env(parent = emptyenv())

# the degree sign is built from its code point, so the source stays ASCII
degree_sign <- intToUtf8(176)

default_unit_aliases <- c(
    "degC" = "C", "deg_C" = "C", "deg C" = "C",
    stats::setNames(c("C", "F"), paste0(degree_sign, c("C", "F"))),
    "celsius" = "C", "degrees_C" = "C", "degree_Celsius" = "C",
    "degrees_Celsius" = "C",
    "kelvin" = "K", "degK" = "K",
    "degF" = "F", "fahrenheit" = "F",
    "meter" = "m", "metre" = "m", "meters" = "m", "metres" = "m",
    "millimeter" = "mm", "millimetre" = "mm", "millimeters" = "mm",
    "millimetres" = "mm",
    "kg m-2" = "kg/m2", "kg m**-2" = "kg/m2", "kg/m^2" = "kg/m2",
    "kg m^-2" = "kg/m2",
    "kg m-2 s-1" = "kg/m2/s", "kg m**-2 s**-1" = "kg/m2/s",
    "kg/m^2/s" = "kg/m2/s", "kg m^-2 s^-1" = "kg/m2/s",
    "mm d-1" = "mm/day", "mm day-1" = "mm/day", "mm/d" = "mm/day",
    "mm per day" = "mm/day",
    "mm month-1" = "mm/month", "mm/mon" = "mm/month",
    "mm h-1" = "mm/h", "mm hr-1" = "mm/h", "mm/hr" = "mm/h", "mm/hour" = "mm/h",
    "m d-1" = "m/day", "m day-1" = "m/day",
    "m s-1" = "m/s", "m s**-1" = "m/s", "km h-1" = "km/h", "km/hr" = "km/h"
)

default_unit_conversions <- tibble::tribble(
    ~from,   ~to,   ~factor, ~offset,
    "K",     "C",   1,       -273.15,
    "C",     "F",   1.8,     32,
    "m",     "mm",  1000,    0,
    "m",     "cm",  100,     0,
    "m",     "km",  0.001,   0,
    "kg/m2", "mm",  1,       0
)

# denominators of rates, in seconds; "month" and "year" depend on the date
time_seconds <- c(s = 1, min = 60, h = 3600, day = 86400)
time_units   <- c(names(time_seconds), "month", "year")

#' Restore the built-in aliases and conversions
#' @noRd
reset_units <- function() {
    c4e_units$aliases     <- default_unit_aliases
    c4e_units$conversions <- default_unit_conversions
    invisible(NULL)
}
reset_units()

#' Add a unit conversion
#'
#' Registers a conversion between two units, and optionally other spellings
#' of them, for the rest of the session. The conversion works in both
#' directions: `value_to = value_from * factor + offset`. Rates per unit of
#' time (e.g. `"in/day"`) do not need registering: they convert through
#' their numerator.
#'
#' @param from,to Unit names, e.g. `"in"` and `"mm"`.
#' @param factor,offset Multiplier and offset from `from` to `to`.
#' @param aliases Optional named character vector of other spellings, e.g.
#'   `c(inch = "in")`.
#'
#' @return The table of registered conversions, invisibly.
#'
#' @seealso [convert_unit()], [list_units()]
#' @export
#'
#' @examples
#' register_unit("in", "mm", factor = 25.4, aliases = c(inch = "in"))
#' convert_unit(data.frame(ID = "1", value = 2), "mm", from = "inch")
register_unit <- function(from, to, factor = 1, offset = 0, aliases = NULL) {
    if (!rlang::is_string(from) || !rlang::is_string(to)) {
        cli::cli_abort("{.arg from} and {.arg to} must be single unit names.")
    }
    if (!rlang::is_scalar_double(factor) && !rlang::is_scalar_integer(factor) ||
        !is.finite(factor) || factor == 0) {
        cli::cli_abort("{.arg factor} must be a finite, non-zero number.")
    }
    if (!is.numeric(offset) || length(offset) != 1 || !is.finite(offset)) {
        cli::cli_abort("{.arg offset} must be a finite number.")
    }
    if (!is.null(aliases) && (!is.character(aliases) || !rlang::is_named(aliases))) {
        cli::cli_abort("{.arg aliases} must be a named character vector, such
                        as {.code c(inch = \"in\")}.")
    }

    table <- c4e_units$conversions
    same <- (table$from == from & table$to == to) |
        (table$from == to & table$to == from)
    c4e_units$conversions <- vctrs::vec_rbind(
        table[!same, ],
        tibble::tibble(from = from, to = to, factor = as.numeric(factor),
                       offset = as.numeric(offset))
    )
    if (!is.null(aliases)) {
        known <- c4e_units$aliases
        c4e_units$aliases <- c(known[setdiff(names(known), names(aliases))], aliases)
    }
    invisible(c4e_units$conversions)
}

#' List the unit conversions
#'
#' @return A tibble with one row per registered conversion: `from`, `to`,
#'   `factor` and `offset`. Each conversion also works in reverse, and rates
#'   per unit of time convert through their numerator.
#'
#' @seealso [register_unit()], [convert_unit()]
#' @export
#'
#' @examples
#' list_units()
list_units <- function() {
    c4e_units$conversions
}

# ==== Names and factors =================================================== ----

#' One name per unit, e.g. "degC", "deg C" and "Celsius" all give "C"
#' @noRd
canonical_unit <- function(unit) {
    if (is.null(unit) || length(unit) != 1 || is.na(unit)) {
        return(NULL)
    }
    unit <- trimws(as.character(unit))
    if (!nzchar(unit)) {
        return(NULL)
    }
    aliases <- c4e_units$aliases
    if (unit %in% names(aliases)) {
        return(unname(aliases[[unit]]))
    }
    loose <- match(tolower(unit), tolower(names(aliases)))
    if (!is.na(loose)) {
        return(unname(aliases[[loose]]))
    }
    unit
}

#' Split a rate into its quantity and time denominator
#'
#' "kg/m2/s" gives base "kg/m2" per "s"; "kg/m2" is not a rate, because "m2"
#' is not a unit of time.
#' @noRd
split_rate <- function(unit) {
    slash <- regexpr("/[^/]*$", unit)
    if (slash < 0) {
        return(list(base = unit, per = NULL))
    }
    per <- substring(unit, slash + 1)
    if (!per %in% time_units) {
        return(list(base = unit, per = NULL))
    }
    list(base = substring(unit, 1, slash - 1), per = per)
}

#' Factor and offset between two simple units, or NULL when unknown
#' @noRd
simple_conversion <- function(from, to) {
    if (identical(from, to)) {
        return(list(factor = 1, offset = 0))
    }
    table <- c4e_units$conversions
    row <- which(table$from == from & table$to == to)
    if (length(row) > 0) {
        return(list(factor = table$factor[row[1]], offset = table$offset[row[1]]))
    }
    row <- which(table$from == to & table$to == from)
    if (length(row) > 0) {
        factor <- table$factor[row[1]]
        return(list(factor = 1 / factor, offset = -table$offset[row[1]] / factor))
    }
    NULL
}

#' How to convert `from` to `to`
#'
#' @return A list with the canonical `from` and `to`, the `factor` and
#'   `offset` of the quantity, `per` (the time denominators of a rate, from
#'   and to, or `NULL`) and `identity` (`TRUE` when nothing changes).
#' @noRd
unit_conversion <- function(from, to, call = rlang::caller_env()) {
    from_c <- canonical_unit(from)
    to_c   <- canonical_unit(to)
    if (is.null(from_c) || is.null(to_c)) {
        cli::cli_abort("Units must be non-empty strings.", call = call)
    }
    if (identical(from_c, to_c)) {
        return(list(from = from_c, to = to_c, factor = 1, offset = 0,
                    per = NULL, identity = TRUE))
    }

    a <- split_rate(from_c)
    b <- split_rate(to_c)
    if (is.null(a$per) != is.null(b$per)) {
        cli::cli_abort(
            c("Can't convert {.val {from_c}} to {.val {to_c}}.",
              "x" = "One is a rate per unit of time and the other is not."),
            call = call)
    }
    quantity <- simple_conversion(a$base, b$base)
    if (is.null(quantity)) {
        cli::cli_abort(
            c("Can't convert {.val {from_c}} to {.val {to_c}}.",
              "i" = "No conversion is registered between {.val {a$base}} and
                     {.val {b$base}}; add one with {.fn register_unit}."),
            call = call)
    }
    if (!is.null(a$per) && quantity$offset != 0) {
        cli::cli_abort(
            "Can't convert rates of {.val {a$base}}: the conversion to
             {.val {b$base}} has an offset.",
            call = call)
    }

    list(from = from_c, to = to_c, factor = quantity$factor,
         offset = quantity$offset, per = if (!is.null(a$per)) c(a$per, b$per),
         identity = FALSE)
}

#' The multiplier of a conversion, per date when months or years are involved
#'
#' @param conv A conversion from `unit_conversion()`.
#' @param dates Dates of the values being converted (one per value, or one).
#' @param time_step Time step of the data; a per-month (per-year) conversion
#'   is only meaningful on monthly (yearly) data.
#' @noRd
rate_factor <- function(conv, dates = NULL, time_step = NULL,
                        call = rlang::caller_env()) {
    if (is.null(conv$per)) {
        return(conv$factor)
    }
    varying <- intersect(conv$per, c("month", "year"))
    if (length(varying) == 2) {
        cli::cli_abort("Can't convert between per-month and per-year rates.",
                       call = call)
    }
    if (length(varying) == 1) {
        if (is.null(dates)) {
            cli::cli_abort(
                "Converting {.val {conv$from}} to {.val {conv$to}} needs the
                 dates of the data.",
                call = call)
        }
        if (!identical(time_step, varying)) {
            step <- time_step %||% "unknown"
            cli::cli_abort(
                "Converting {.val {conv$from}} to {.val {conv$to}} needs data
                 with time step {.val {varying}}; the input's time step is
                 {.val {step}}.",
                call = call)
        }
    }
    conv$factor * period_seconds(conv$per[2], dates) /
        period_seconds(conv$per[1], dates)
}

period_seconds <- function(per, dates) {
    if (per %in% names(time_seconds)) {
        return(time_seconds[[per]])
    }
    dates <- parse_date_label(dates)
    days <- switch(per,
                   month = lubridate::days_in_month(dates),
                   year  = 365 + lubridate::leap_year(dates))
    unname(as.numeric(days)) * 86400
}

#' Time step of a regular series of dates, or NULL
#' @noRd
infer_time_step <- function(dates) {
    if (is.null(dates)) {
        return(NULL)
    }
    dates <- sort(unique(dates[!is.na(dates)]))
    if (length(dates) < 2) {
        return(NULL)
    }
    gap <- stats::median(as.numeric(difftime(dates[-1], dates[-length(dates)],
                                             units = "days")))
    if (gap <= 1.5 / 24) return("hour")
    if (gap >= 0.5 && gap <= 1.5) return("day")
    if (gap >= 27 && gap <= 32) return("month")
    if (gap >= 360 && gap <= 370) return("year")
    NULL
}

#' Thresholds must be in the data's unit
#'
#' Returns the unit to label the thresholds with: the explicit one when it
#' agrees with the data, else the data's own (announced). Contradicting the
#' data is an error pointing at `convert_unit()`.
#' @noRd
resolve_unit <- function(unit, meta, call = rlang::caller_env()) {
    check_meta_agrees(
        canonical_unit(unit), canonical_unit(meta$unit), "unit",
        hint = "Thresholds are read in the data's unit. Convert the data first,
                e.g. with {.code convert_unit(x, \"C\")}.",
        call = call)
    c4e_default(unit, meta$unit, "unit", required = FALSE, call = call)
}

# ==== convert_unit() ====================================================== ----

#' Convert data to another unit
#'
#' Converts a raster or a table to another unit of measure and records the
#' new unit, so later steps read thresholds in the right unit.
#'
#' * On a `SpatRaster`, the unit is read from [terra::units()] and written
#'   back; layer names and dates are kept.
#' * On a `c4e_tbl`, the unit comes from the metadata. The base series is
#'   converted: the date columns of a wide table, or `value` in a long one.
#'   Indicator columns that are amounts are converted too. Percentiles are
#'   levels and take the full conversion. Excesses over a threshold are
#'   differences, so a K to C conversion leaves them unchanged. Counts of days
#'   and spell lengths never change. Numeric thresholds in the registry are
#'   converted, so `day_abv_303.15` in K is recorded as a threshold of 30 C.
#' * On a plain data frame, `from` is required; the result is a `c4e_tbl`.
#'
#' Unit names are matched loosely: `"degC"`, `"deg C"` and `"Celsius"` all mean
#' `"C"`, and `"kg m-2 s-1"` means `"kg/m2/s"`. Rates per unit of time
#' convert through their numerator: `"kg/m2/s"` to `"mm/day"` multiplies by
#' 86400. Months and years have varying lengths, so `"mm/day"` to
#' `"mm/month"` multiplies each value by the days in its month and needs
#' monthly data.
#'
#' @param x A `SpatRaster`, a `c4e_tbl` or a data frame.
#' @param to Unit to convert to.
#' @param from Unit to convert from. Defaults to the unit recorded in `x`.
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional columns to
#'   convert instead of the base series. Indicator columns are still handled
#'   from the registry.
#' @param ... Unused.
#'
#' @return `x` in the new unit, of the same class (a `c4e_tbl` for data
#'   frames).
#'
#' @seealso [register_unit()], [list_units()]
#' @export
#'
#' @examples
#' tmax <- terra::rast(
#'   system.file("extdata", "tmax_daily.tif", package = "climatic4economist"))
#' terra::units(tmax)[1]
#' tmax_c <- convert_unit(tmax[[1:3]], "C")
#' terra::units(tmax_c)[1]
#'
#' wide <- data.frame(ID = "1", X2022.01.01 = 300, X2022.01.02 = 305)
#' convert_unit(wide, "C", from = "K")
convert_unit <- function(x, to, from = NULL, ...) {
    UseMethod("convert_unit")
}

#' @rdname convert_unit
#' @export
convert_unit.SpatRaster <- function(x, to, from = NULL, ...) {
    from <- from %||% raster_unit(x)
    if (is.null(from)) {
        cli::cli_abort("{.arg x} records no unit; give {.arg from}.")
    }
    conv <- unit_conversion(from, to)
    if (conv$identity) {
        return(x)
    }

    dates <- NULL
    step  <- NULL
    if (!is.null(conv$per) && terra::has.time(x)) {
        dates <- terra::time(x)
        step  <- infer_time_step(dates)
    }
    factor <- rate_factor(conv, dates, step)

    out <- x * factor + conv$offset
    names(out) <- names(x)
    if (terra::has.time(x)) {
        terra::time(out) <- terra::time(x)
    }
    terra::units(out) <- conv$to
    out
}

#' @rdname convert_unit
#' @export
convert_unit.c4e_tbl <- function(x, to, from = NULL, cols = NULL, ...) {
    started <- Sys.time()
    meta <- c4e_meta(x)
    from <- c4e_default(from, meta$unit, "from", field = "unit")
    conv <- unit_conversion(from, to)
    if (conv$identity) {
        return(x)
    }

    data <- tibble::as_tibble(x)
    registry <- meta$indicators
    level_cols <- if (rlang::quo_is_null(rlang::enquo(cols))) {
        series_columns(data, meta)
    } else {
        names(dplyr::select(data, {{ cols }}))
    }
    level_cols <- setdiff(level_cols, names(registry))

    factor_of <- column_factors(conv, data, meta)
    for (col in level_cols) {
        data[[col]] <- data[[col]] * factor_of(col) + conv$offset
    }

    for (name in names(registry)) {
        entry <- registry[[name]]
        if (!identical(canonical_unit(entry$unit %||% meta$unit %||% from), conv$from)) {
            next
        }
        role <- unit_role(entry, registry)
        if (role != "none") {
            offset <- if (role == "level") conv$offset else 0
            data[[name]] <- data[[name]] * factor_of(name) + offset
        }
        if (is.numeric(entry$threshold)) {
            entry$threshold <- entry$threshold * rate_factor(conv) + conv$offset
        }
        if (!is.null(entry$unit)) {
            entry$unit <- conv$to
        }
        registry[[name]] <- entry
    }

    meta$indicators <- registry
    meta$unit <- conv$to
    meta <- c4e_record(meta, "convert_unit", list(to = to, from = from), started)
    new_c4e_tbl(data, meta)
}

#' @rdname convert_unit
#' @export
convert_unit.data.frame <- function(x, to, from = NULL, cols = NULL, ...) {
    if (is.null(from)) {
        cli::cli_abort("A plain data frame records no unit; give {.arg from}.")
    }
    x <- new_c4e_tbl(x, guess_meta(x, unit = from))
    convert_unit.c4e_tbl(x, to = to, from = from, cols = {{ cols }}, ...)
}

# ==== Helpers for convert_unit() ========================================== ----

raster_unit <- function(x, call = rlang::caller_env()) {
    units <- unique(terra::units(x))
    units <- units[!is.na(units) & nzchar(units)]
    if (length(units) > 1) {
        cli::cli_abort("The layers of {.arg x} have different units:
                        {.val {units}}.", call = call)
    }
    if (length(units) == 0) NULL else units
}

#' Metadata for a plain data frame, guessed from its columns
#' @noRd
guess_meta <- function(x, unit) {
    has_dates <- any(grepl(date_pattern(), names(x)))
    list(
        key      = tryCatch(resolve_key(x), error = function(e) NULL),
        unit     = unit,
        shape    = if (has_dates) "wide" else if ("value" %in% names(x)) "long",
        date_col = if ("date" %in% names(x)) "date"
    )
}

#' Columns holding the base series: date columns when wide, `value` when long
#' @noRd
series_columns <- function(data, meta) {
    date_cols <- grep(date_pattern(), names(data), value = TRUE)
    value_col <- intersect("value", names(data))
    switch(meta$shape %||% "unknown",
           wide    = date_cols,
           long    = value_col,
           lookup  = character(),
           summary = character(),
           if (length(date_cols) > 0) date_cols else value_col)
}

#' How a converted indicator column changes: as a level, as a difference, or
#' not at all (counts, lengths, standardised values)
#' @noRd
unit_role <- function(entry, registry) {
    switch(entry$kind,
           excess = "difference",
           pct    = "level",
           par    = if (isTRUE(entry$stat %in% c("mean", "median", "min", "max",
                                                 "quantile"))) {
               "level"
           } else if (isTRUE(entry$stat %in% c("sd", "range", "iqr", "mad"))) {
               "difference"
           } else {
               "none"
           },
           agg    = if (identical(registry[[entry$base %||% ""]]$kind, "excess")) {
               "difference"
           } else {
               "none"
           },
           "none")
}

#' A function giving the multiplier for one column
#'
#' Fixed conversions use one factor. Per-month or per-year rates use the
#' date of the column (wide tables) or of each row (long tables).
#' @noRd
column_factors <- function(conv, data, meta, call = rlang::caller_env()) {
    if (is.null(conv$per)) {
        return(function(col) conv$factor)
    }
    date_cols <- grep(date_pattern(), names(data), value = TRUE)
    col_dates <- stats::setNames(parse_date_label(to_date(date_cols)), date_cols)
    date_col  <- meta$date_col %||% intersect("date", names(data))
    row_dates <- if (length(date_col) == 1) parse_date_label(data[[date_col]])
    step <- meta$time_step %||%
        infer_time_step(if (length(col_dates) > 0) col_dates else row_dates)

    function(col) {
        dates <- if (col %in% date_cols) col_dates[[col]] else row_dates
        rate_factor(conv, dates, step, call = call)
    }
}
