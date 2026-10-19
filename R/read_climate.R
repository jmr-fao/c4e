# Reading climate rasters with their context (plan §2, §9.4, §9.5, §11.7).

# ==== Variables =========================================================== ----

# spellings of variables in common datasets, mapped to the package's names
variable_aliases <- c(
    t2m = "tmean", tas = "tmean", tair = "tmean", tmean = "tmean",
    tavg = "tmean",
    mx2t = "tmax", tasmax = "tmax", tmax = "tmax",
    mn2t = "tmin", tasmin = "tmin", tmin = "tmin",
    tp = "pre", pr = "pre", pre = "pre", prec = "pre", precip = "pre",
    prcp = "pre", precipitation = "pre", rainf = "pre", rain = "pre",
    e = "evap", evap = "evap", pev = "pet", pet = "pet",
    d2m = "dewpoint",
    aez = "aez", urca = "urca", landcover = "landcover",
    pop = "pop", population = "pop"
)
categorical_variables <- c("aez", "urca", "landcover")
count_variables       <- c("pop")
amount_variables      <- c("pre", "evap", "pet")
raster_kinds          <- c("continuous", "count", "categorical")

#' The package's name for a variable, e.g. "t2m" gives "tmean"
#' @noRd
standard_variable <- function(variable) {
    if (is.null(variable)) {
        return(NULL)
    }
    known <- variable_aliases[tolower(variable)]
    if (is.na(known)) variable else unname(known)
}

#' Find a known variable among the words of file and variable names
#'
#' One-letter spellings (ERA5's "e") are only used when they are the whole
#' name, so they are not found inside unrelated words.
#' @noRd
guess_variable <- function(candidates) {
    candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
    for (candidate in candidates) {
        if (tolower(candidate) %in% names(variable_aliases)) {
            return(standard_variable(candidate))
        }
        words <- strsplit(tolower(candidate), "[^a-z0-9]+")[[1]]
        words <- words[nchar(words) > 1 & words %in% names(variable_aliases)]
        if (length(words) > 0) {
            return(standard_variable(words[1]))
        }
    }
    NULL
}

default_kind <- function(variable) {
    if (isTRUE(variable %in% categorical_variables)) return("categorical")
    if (isTRUE(variable %in% count_variables)) return("count")
    "continuous"
}

# ==== Sources ============================================================= ----

c4e_sources <- new.env(parent = emptyenv())

has_era5_names <- function(x) any(grepl("_valid_time=", names(x), fixed = TRUE))

builtin_sources <- function() {
    list(
        era5 = list(
            detect   = function(x, files) {
                has_era5_names(x) || any(grepl("era5", basename(files), ignore.case = TRUE))
            },
            time     = function(x, files) {
                if (!has_era5_names(x)) return(NULL)
                seconds <- as.numeric(sub(".*_valid_time=", "", names(x)))
                as.POSIXct(seconds, origin = "1970-01-01", tz = "UTC")
            },
            variable = function(x, files) {
                if (has_era5_names(x)) sub("_valid_time=.*", "", names(x)[1])
            }
        ),
        chirps = list(
            detect   = "^chirps",
            variable = "pre",
            unit     = function(x, files, step) {
                switch(step %||% "none", day = "mm/day", month = "mm/month",
                       year = "mm/year", NULL)
            }
        ),
        wfde5 = list(detect = "wfde5"),
        gaez = list(
            detect   = "gaez",
            variable = function(x, files) {
                if (any(grepl("aez", c(basename(files), names(x)), ignore.case = TRUE))) "aez"
            },
            kind     = function(x, files) {
                if (any(grepl("aez", c(basename(files), names(x)), ignore.case = TRUE))) {
                    "categorical"
                }
            }
        )
    )
}

#' Restore the built-in data sources
#' @noRd
reset_sources <- function() {
    c4e_sources$user <- list()
    invisible(NULL)
}
reset_sources()

all_sources <- function() {
    c(c4e_sources$user, builtin_sources())
}

#' Teach read_climate() a data source
#'
#' Registers the conventions of a dataset, so [read_climate()] recognises its
#' files and records the right variable, unit, kind and dates. Registered
#' sources are tried before the built-in ones (`era5`, `chirps`, `wfde5`,
#' `gaez`), for the rest of the session.
#'
#' Each of `variable`, `unit` and `kind` is either a fixed string or a
#' function of the raster and its file names (`unit` also receives the time
#' step) returning a string or `NULL`.
#'
#' @param name Name of the source, e.g. `"agera5"`.
#' @param detect A regular expression matched, ignoring case, against the
#'   file names and layer names; or a function of the raster and its file
#'   names returning `TRUE` when the files belong to the source.
#' @param variable,unit,kind Conventions of the source; see Details.
#' @param time Optional function of the raster and its file names returning
#'   one date (or date-time) per layer, or `NULL`.
#'
#' @return The names of the registered sources, invisibly.
#'
#' @seealso [read_climate()], [list_sources()]
#' @export
#'
#' @examples
#' register_source("agera5", detect = "AgERA5", unit = "C")
#' list_sources()
register_source <- function(name, detect, variable = NULL, unit = NULL,
                            kind = NULL, time = NULL) {
    if (!rlang::is_string(name)) {
        cli::cli_abort("{.arg name} must be a single string.")
    }
    if (!rlang::is_string(detect) && !is.function(detect)) {
        cli::cli_abort("{.arg detect} must be a regular expression or a function.")
    }
    if (!is.null(time) && !is.function(time)) {
        cli::cli_abort("{.arg time} must be a function of the raster and its files.")
    }
    if (rlang::is_string(kind) && !kind %in% raster_kinds) {
        cli::cli_abort("{.arg kind} must be one of {.or {.val {raster_kinds}}}.")
    }
    source <- purrr::compact(list(detect = detect, variable = variable,
                                  unit = unit, kind = kind, time = time))
    c4e_sources$user[[name]] <- source
    invisible(list_sources())
}

#' List the data sources read_climate() recognises
#'
#' @return A character vector of source names, registered ones first.
#' @seealso [register_source()]
#' @export
#'
#' @examples
#' list_sources()
list_sources <- function() {
    names(all_sources())
}

source_matches <- function(source, x, files) {
    detect <- source$detect
    if (is.function(detect)) {
        return(isTRUE(detect(x, files)))
    }
    any(grepl(detect, c(basename(files), names(x)), ignore.case = TRUE))
}

#' Evaluate a convention: a fixed value, or a function of the raster
#' @noRd
source_value <- function(rule, ...) {
    if (is.null(rule)) return(NULL)
    if (is.function(rule)) {
        args <- list(...)[seq_len(min(length(list(...)), length(formals(rule))))]
        return(do.call(rule, args))
    }
    rule
}

# ==== Dates =============================================================== ----

#' Dates written in layer names, when every name holds one
#' @noRd
dates_from_names <- function(layer_names) {
    parsed <- parse_date_label(to_date(layer_names))
    if (length(parsed) == 0 || anyNA(parsed) || anyDuplicated(parsed) > 0) {
        return(NULL)
    }
    parsed
}

#' Dates written in file names, one per file, e.g. "chirps-v2.0.2021.01.tif"
#' @noRd
dates_from_files <- function(files) {
    pattern <- "(19|20)[0-9]{2}[._-]?(0[1-9]|1[0-2])([._-]?(0[1-9]|[12][0-9]|3[01]))?"
    found <- regmatches(basename(files), regexpr(pattern, basename(files)))
    if (length(found) != length(files)) {
        return(NULL)
    }
    dates_from_names(gsub("[._]", "-", found))
}

#' Midnight date-times become dates
#' @noRd
normalise_dates <- function(dates) {
    if (inherits(dates, "POSIXt")) {
        clock <- format(dates, "%H:%M:%S", tz = "UTC")
        if (all(clock == "00:00:00", na.rm = TRUE)) {
            return(as.Date(format(dates, "%Y-%m-%d", tz = "UTC")))
        }
    }
    dates
}

format_layer_dates <- function(dates) {
    if (inherits(dates, "POSIXt")) {
        return(format(dates, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
    }
    format(dates, "%Y-%m-%d")
}

# ==== read_climate() ====================================================== ----

#' Read a climate raster with its context
#'
#' Reads one or more raster files and records what later steps need: the
#' dates of the layers, the variable, its unit, the time step and whether the
#' values are continuous, counts or categories. Layers are named by their
#' ISO dates. Explicit arguments always win over what the files say.
#'
#' Dates come, in order of preference, from the source's convention (ERA5
#' layer names such as `t2m_valid_time=1704067200`), from the dates stored in
#' the file, from layer names that are dates, or from dates in the file names
#' when there is one file per layer (CHIRPS). The variable is taken from the
#' source or found in the variable and file names, and is standardised:
#' `t2m` becomes `tmean`, `tp` and `precip` become `pre`. See
#' [register_source()] to add a dataset's conventions.
#'
#' While reading, codes in `na_value` become `NA`, and a raster with
#' longitudes from 0 to 360 is rotated to -180 to 180 so it lines up with
#' survey coordinates.
#'
#' @param path Path(s) to raster files, or a `SpatRaster`.
#' @param variable Variable name, e.g. `"tmax"` or `"pre"`.
#' @param unit Unit of the values, e.g. `"K"` or `"mm/day"`. This declares
#'   the unit; to change the values, use [convert_unit()].
#' @param time_step One of `"hour"`, `"day"`, `"month"`, `"year"`. Inferred
#'   from the dates when `NULL`.
#' @param kind One of `"continuous"`, `"count"`, `"categorical"`. Decides how
#'   later steps aggregate the values (mean, sum, mode). Inferred from the
#'   variable when `NULL`.
#' @param source Name of a registered source, to skip detection.
#' @param na_value Values to treat as missing, e.g. `128` for URCA.
#' @param label Name used in progress messages and later steps. Defaults to
#'   the file name.
#' @param rotate When `TRUE`, rotate rasters with longitudes beyond 180.
#'
#' @return A `SpatRaster` with dates, unit and package metadata; see
#'   [raster_meta()].
#'
#' @seealso [raster_meta()], [aggregate_time()], [convert_unit()]
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "climatic4economist"))
#' raster_meta(tmax)[c("variable", "unit", "time_step")]
read_climate <- function(path, variable = NULL, unit = NULL, time_step = NULL,
                         kind = NULL, source = NULL, na_value = NULL,
                         label = NULL, rotate = TRUE) {
    if (inherits(path, "SpatRaster")) {
        x <- path
        files <- terra::sources(x)
    } else {
        if (!is.character(path) || length(path) == 0) {
            cli::cli_abort("{.arg path} must be file paths or a {.cls SpatRaster}.")
        }
        missing_files <- path[!file.exists(path)]
        if (length(missing_files) > 0) {
            cli::cli_abort("File{?s} not found: {.file {missing_files}}.")
        }
        x <- terra::rast(path)
        files <- path
    }
    files <- files[!is.na(files) & nzchar(files)]
    stored <- stored_raster_meta(x)
    # context stored for another variable (e.g. a raster built on a template
    # with terra::rast(template, vals = ...)) does not describe this one
    if (!is.null(variable) && !is.null(stored$variable) &&
        !identical(standard_variable(variable), stored$variable)) {
        stored <- lapply(stored, \(value) NULL)
    }

    # which dataset the files come from
    sources <- all_sources()
    if (!is.null(source)) {
        if (!source %in% names(sources)) {
            cli::cli_abort("Unknown {.arg source} {.val {source}}; known sources
                            are {.val {names(sources)}}.")
        }
        source_name <- source
    } else {
        hits <- names(sources)[vapply(sources, source_matches, logical(1),
                                      x = x, files = files)]
        source_name <- if (length(hits) > 0) hits[1] else stored$source
    }
    rules <- sources[[source_name %||% ""]] %||% list()

    # conventions that read the original layer names, before they become dates
    source_variable <- source_value(rules$variable, x, files)
    source_kind     <- source_value(rules$kind, x, files)
    name_variable   <- guess_variable(c(terra::varnames(x),
                                        tools::file_path_sans_ext(basename(files))))

    # dates and layer names
    dates <- source_value(rules$time, x, files) %||%
        (if (terra::has.time(x) && !all(is.na(terra::time(x)))) terra::time(x)) %||%
        dates_from_names(names(x)) %||%
        (if (length(files) == terra::nlyr(x)) dates_from_files(files))
    if (!is.null(dates)) {
        dates <- normalise_dates(dates)
        terra::time(x) <- dates
        names(x) <- format_layer_dates(dates)
    }
    step <- time_step %||% stored$time_step %||% infer_time_step(dates)
    if (!is.null(step) && !step %in% c4e_time_steps) {
        cli::cli_abort("{.arg time_step} must be one of {.or {.val {c4e_time_steps}}}.")
    }

    # variable, unit, kind
    variable <- standard_variable(
        variable %||% stored$variable %||% source_variable %||% name_variable
    )
    file_unit <- raster_unit(x)
    if (!is.null(unit) && !is.null(file_unit) &&
        !identical(canonical_unit(unit), canonical_unit(file_unit))) {
        given <- canonical_unit(unit)
        c4e_inform(c(
            "i" = "The file records the unit {.val {file_unit}}; recording
                   {.val {given}} as given.",
            " " = "To change the values, use {.fn convert_unit}."
        ))
    }
    new_unit <- canonical_unit(unit) %||% canonical_unit(file_unit) %||%
        canonical_unit(source_value(rules$unit, x, files, step))
    if (!is.null(new_unit)) {
        terra::units(x) <- new_unit
    }
    kind <- kind %||% stored$kind %||% source_kind %||% default_kind(variable)
    if (!kind %in% raster_kinds) {
        cli::cli_abort("{.arg kind} must be one of {.or {.val {raster_kinds}}}.")
    }

    # cleaning
    if (!is.null(na_value)) {
        x <- keep_raster_meta(terra::subst(x, na_value, NA), x)
    }
    if (rotate && is_zero_to_360(x)) {
        c4e_inform("Rotating longitudes from 0 to 360 into -180 to 180.")
        x <- keep_raster_meta(terra::rotate(x), x)
    }

    label <- label %||% stored$label %||%
        (if (length(files) > 0) tools::file_path_sans_ext(basename(files[1])))
    x <- set_raster_meta(x, list(variable = variable, kind = kind,
                                 source = source_name, label = label,
                                 time_step = step))
    inform_read(x)
    x
}

#' Longitudes running from 0 to 360 rather than -180 to 180
#' @noRd
is_zero_to_360 <- function(x) {
    terra::is.lonlat(x, warn = FALSE) &&
        terra::xmin(x) >= -1e-6 && terra::xmax(x) > 180 + 1e-6
}

#' One line saying what was read
#' @noRd
inform_read <- function(x) {
    meta <- raster_meta(x)
    series <- paste0(meta$variable %||% "values",
                     if (!is.null(meta$unit)) paste0(" [", meta$unit, "]"))
    step <- switch(meta$time_step %||% "none", hour = "hourly", day = "daily",
                   month = "monthly", year = "yearly", "static")
    period <- if (!is.null(meta$date_range)) {
        paste(format(meta$date_range), collapse = " to ")
    }
    n <- terra::nlyr(x)
    layers <- paste(n, if (n == 1) "layer" else "layers")
    source <- if (!is.null(meta$source)) paste0(" (", meta$source, ")")
    what <- paste(c(series, step, period, layers), collapse = ", ")
    label <- meta$label %||% "raster"
    c4e_inform("Read {label}: {what}{source}.")
}
