# The high-level wrappers (plan §12): the whole chain from a survey and a
# raster, with few arguments. Each stage calls the step functions, so the
# result's history shows the equivalent step-by-step code.

# ==== Shared machinery ===================================================== ----

#' Column names from tidy-select arguments, or NULL when not given
#' @noRd
column_names <- function(lat, lon, id, interview) {
    name_of <- function(quo) if (rlang::quo_is_null(quo)) NULL else rlang::as_name(quo)
    list(lat = name_of(lat), lon = name_of(lon), id = name_of(id),
         interview = name_of(interview))
}

#' The survey's distinct locations, prepared once
#' @noRd
survey_locations <- function(survey, cols, call = rlang::caller_env()) {
    meta <- c4e_meta(survey)
    if (!is.null(meta$survey$lon) && !is.null(meta$survey$lat)) {
        recorded <- meta$survey
        recorded$id <- cols$id %||% recorded$id
        recorded$interview <- cols$interview %||% recorded$interview
        return(update_meta(survey, survey = purrr::compact(recorded)))
    }
    lat <- cols$lat %||% find_column(survey, c("lat", "latitude", "y"), "lat", call)
    lon <- cols$lon %||% find_column(survey, c("lon", "long", "longitude", "x"), "lon", call)
    prepare_coord(survey, lat_var = !!rlang::sym(lat), lon_var = !!rlang::sym(lon),
                  id = !!cols$id, interview = !!cols$interview)
}

find_column <- function(survey, candidates, arg, call) {
    found <- intersect(candidates, names(survey))
    if (length(found) == 0) {
        cli::cli_abort("Give {.arg {arg}}, the survey's {arg} column.", call = call)
    }
    c4e_inform("Using {.field {found[1]}} as {.arg {arg}}.")
    found[1]
}

#' A raster read with its context, or an already extracted table
#' @noRd
climate_input <- function(climate, variable = NULL, call = rlang::caller_env()) {
    if (is_c4e_tbl(climate)) {
        return(climate)
    }
    if (is.character(climate) || inherits(climate, "SpatRaster")) {
        return(read_climate(climate, variable = variable))
    }
    cli::cli_abort("{.arg climate} must be a raster, a file path or an extracted
                    table.", call = call)
}

input_meta <- function(x) {
    if (inherits(x, "SpatRaster")) raster_meta(x) else c4e_meta(x)
}

#' The unit the thresholds are read in, converting where it is clearly meant
#'
#' With a preset, its unit; without one, Kelvin data with thresholds below
#' 100 are taken to be in Celsius, and precipitation in metres or kg/m2/s is
#' taken to be in millimetres.
#' @noRd
target_unit <- function(meta, spec, thresholds, unit) {
    if (!is.null(unit)) return(canonical_unit(unit))
    if (!is.null(spec$unit)) return(spec$unit)
    from <- canonical_unit(meta$unit)
    if (identical(from, "K") && length(thresholds) > 0 && all(abs(thresholds) < 100)) {
        return("C")
    }
    if (identical(meta$variable, "pre") && isTRUE(from %in% c("m", "m/day", "kg/m2/s"))) {
        return(if (identical(from, "m")) "mm" else "mm/day")
    }
    NULL
}

#' Convert an extracted table to the unit the thresholds are in, and say so
#' @noRd
to_unit <- function(x, unit) {
    from <- canonical_unit(c4e_meta(x, "unit"))
    if (is.null(unit) || is.null(from) || identical(from, canonical_unit(unit))) {
        return(x)
    }
    c4e_inform("Converting {.val {from}} to {.val {unit}} to read the thresholds.")
    suppressMessages(convert_unit(x, unit))
}

#' Run a wrapper once per survey of a named list, and stack the results
#' @noRd
map_surveys <- function(surveys, run) {
    if (!rlang::is_named(surveys)) {
        names(surveys) <- paste0("survey_", seq_along(surveys))
    }
    results <- purrr::imap(surveys, \(survey, name) {
        # added per table: .names_to would bind through a plain tibble and
        # drop the registry
        dplyr::relocate(dplyr::mutate(run(survey, name), survey = name), "survey")
    })
    out <- vctrs::vec_rbind(!!!unname(results))
    meta <- c4e_meta(out)
    update_meta(out, survey_cols = unique(c("survey", meta$survey_cols)))
}

is_survey_list <- function(survey) {
    is.list(survey) && !is.data.frame(survey)
}

#' Attach each location's division to the survey locations
#' @noRd
locations_in_divisions <- function(locations, points, boundaries) {
    key <- c4e_meta(locations, "key") %||% "ID"
    hits <- terra::extract(boundaries, points)
    division <- tibble::tibble(!!key := terra::values(points)[[key]][hits$id.y],
                               ID_adm_div = as.character(hits$ID_adm_div))
    division <- division[!duplicated(division[[key]]), , drop = FALSE]
    dplyr::left_join(locations, division, by = key)
}

#' The opening block: what is computed, on what
#' @noRd
inform_spec <- function(title, meta, lines, locations) {
    survey_meta <- c4e_meta(locations)
    n_locations <- length(unique(locations[[survey_meta$key]]))
    n_units <- if (!is.null(survey_meta$survey$id)) {
        length(unique(locations[[survey_meta$survey$id]]))
    } else {
        nrow(locations)
    }
    series <- series_label(list(variable = meta$variable %||% "values",
                                unit = meta$unit, time_step = meta$time_step))
    period <- if (!is.null(meta$date_range)) paste(meta$date_range, collapse = " to ")
    c4e_inform(c(
        "i" = "{title}: {series}{if (!is.null(period)) paste0(', ', period) else ''}",
        stats::setNames(lines, rep(" ", length(lines))),
        " " = "{n_locations} locations, {n_units} survey units"
    ))
}

#' The dry-run plan
#' @noRd
inform_plan <- function(steps) {
    c4e_inform(c("i" = "Dry run: nothing computed. The steps would be:",
                 stats::setNames(steps, rep("*", length(steps)))))
}

describe_thresholds <- function(above, below, p, unit, heatwave, min_spell, spells) {
    parts <- c(
        if (!is.null(above)) paste0("above ", paste(above, collapse = ", "),
                                    if (!is.null(unit)) paste0(" ", unit)),
        if (!is.null(below)) paste0("below ", paste(below, collapse = ", "),
                                    if (!is.null(unit)) paste0(" ", unit)),
        if (!is.null(p)) paste0("percentiles ", paste(p * 100, collapse = ", ")),
        if (!is.null(heatwave)) paste0("WMO heatwaves (", heatwave$excess, " above the monthly mean)"),
        if (spells || !is.null(heatwave)) paste0("spells of ", min_spell, "+ days")
    )
    paste(parts, collapse = "; ")
}

# ==== weather_extremes() ==================================================== ----

#' Extreme weather before each interview, in one call
#'
#' Runs the whole chain from a survey and a daily climate raster to one row
#' per household and lag: the number of days beyond thresholds or
#' percentiles, the excess over them, and the spells they form, over the
#' window before each interview. The result's [c4e_history()] shows the
#' equivalent step-by-step code, to copy and adapt.
#'
#' The chain: [prepare_coord()], [georef_coord()], [read_climate()],
#' [extract_by_coord()] (or [extract_cell_by_poly()] and [aggregate_to_adm()]
#' with `boundaries`), [convert_unit()] when needed,
#' [calc_threshold_day()] and/or [calc_percentile()] with
#' [calc_percentile_day()] (or [calc_heatwave()]), [calc_spell()], and
#' [summarise_by_interview()].
#'
#' Pick the indicators with a `preset` (see [list_presets()]) or with
#' `above`, `below` and `p`; explicit arguments override the preset.
#' Thresholds are read in the data's unit, except that Kelvin data with
#' thresholds below 100 are converted to Celsius, and precipitation in
#' metres to millimetres, with a message. Percentiles of precipitation leave
#' out days below 0.1 mm unless `control` says otherwise.
#'
#' `survey` may be a named list of surveys (waves, countries); each is
#' processed in turn and the results are stacked with a `survey` column.
#'
#' @param survey The survey: a data frame with coordinates, a household
#'   identifier and interview dates, or a table from [prepare_coord()]; or a
#'   named list of them.
#' @param climate A daily raster (file path or `SpatRaster`), or a table
#'   already extracted at the survey locations.
#' @param lat,lon,id,interview <[`tidy-select`][dplyr::dplyr_tidy_select]>
#'   Survey columns: coordinates (found by name when left out), household
#'   identifier and interview date. Not needed after [prepare_coord()].
#' @param preset Name of a preset, e.g. `"heat"` or `"wet_days_p95"`.
#' @param above,below Absolute thresholds, in the data's unit.
#' @param p Probabilities for relative thresholds, e.g. `c(0.9, 0.95)`.
#' @param spells When `TRUE`, add spells of the flagged days.
#' @param min_spell Minimum spell length in days; default 2.
#' @param window The reference window; default the year before the
#'   interview, see [window_lag()].
#' @param boundaries Optional administrative divisions: indicators are then
#'   computed per cell and averaged per division (area shares).
#' @param baseline Optional dates `c(from, to)` for the percentiles.
#' @param unit Unit of the thresholds, when the data's should not be used.
#' @param control Further options, see [extremes_control()].
#'
#' @return A `c4e_tbl` with one row per household and lag; with
#'   `keep_steps`, a list of the intermediate tables; with `dry_run`,
#'   `NULL`.
#'
#' @seealso [climate_indices()], [list_presets()], [write_stata()]
#' @export
#'
#' @examples
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' survey$interview <- as.Date(survey$interview)
#'
#' weather_extremes(survey,
#'                  system.file("extdata", "tmax_daily.tif", package = "c4e"),
#'                  id = hhid, interview = interview, preset = "heat")
weather_extremes <- function(survey, climate, lat = NULL, lon = NULL, id = NULL,
                             interview = NULL, preset = NULL, above = NULL,
                             below = NULL, p = NULL, spells = TRUE,
                             min_spell = NULL, window = NULL, boundaries = NULL,
                             baseline = NULL, unit = NULL,
                             control = extremes_control()) {
    cols <- column_names(rlang::enquo(lat), rlang::enquo(lon), rlang::enquo(id),
                         rlang::enquo(interview))
    if (is_survey_list(survey)) {
        return(map_surveys(survey, \(one, name) {
            control$label <- name
            weather_extremes(one, climate, lat = !!cols$lat, lon = !!cols$lon,
                             id = !!cols$id, interview = !!cols$interview,
                             preset = preset, above = above, below = below, p = p,
                             spells = spells, min_spell = min_spell, window = window,
                             boundaries = boundaries, baseline = baseline,
                             unit = unit, control = control)
        }))
    }
    if (isFALSE(control$verbose)) {
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
    }
    env <- environment()
    stage <- function(msg) c4e_progress_step(msg, .envir = env)

    spec <- preset_spec(preset, "weather_extremes")
    above <- above %||% spec$above
    below <- below %||% spec$below
    p <- p %||% spec$p
    heatwave <- if (is.null(c(above, below, p))) spec$heatwave
    min_spell <- min_spell %||% heatwave$min_spell %||% spec$min_spell %||% 2L
    if (is.null(c(above, below, p)) && is.null(heatwave)) {
        cli::cli_abort("Give a {.arg preset}, or thresholds with {.arg above},
                        {.arg below} or {.arg p}.")
    }
    window <- window %||% window_lag("1 year")

    locations <- survey_locations(survey, cols)
    points <- georef_coord(locations)
    climate <- climate_input(climate)
    meta <- input_meta(climate)
    check_preset_data(spec, meta, preset)
    unit_to <- target_unit(meta, spec, c(above, below), unit)
    exclude_below <- control$exclude_below %||% spec$exclude_below %||%
        (if (!is.null(p) && identical(meta$variable, "pre")) 0.1)

    inform_spec(
        paste0("weather_extremes", if (!is.null(preset)) paste0(" (", preset, ")")),
        meta,
        c(describe_thresholds(above, below, p, unit_to %||% meta$unit, heatwave,
                              min_spell, spells),
          paste("window:", describe_window(window))),
        locations)

    if (isTRUE(control$dry_run)) {
        layers <- if (inherits(climate, "SpatRaster")) terra::nlyr(climate) else NA
        inform_plan(c(
            paste0("extract ", layers, " layers at ", nrow(terra::unique(points)),
                   " locations", if (!is.null(boundaries)) " (cells of the divisions)"),
            if (!is.null(unit_to)) paste0("convert to ", unit_to),
            paste0("indicators: ", describe_thresholds(above, below, p, unit_to,
                                                       heatwave, min_spell, spells)),
            paste0("summaries per household: ", describe_window(window))
        ))
        return(invisible(NULL))
    }

    stage("Extracting {meta$variable %||% 'the data'}")
    by <- NULL
    if (is_c4e_tbl(climate)) {
        extracted <- climate
    } else if (!is.null(boundaries)) {
        extracted <- extract_cell_by_poly(climate, boundaries, chunk = control$chunk)
        locations <- locations_in_divisions(locations, points, boundaries)
        by <- "ID_adm_div"
    } else {
        extracted <- extract_by_coord(climate, points, chunk = control$chunk)
    }
    extracted <- to_unit(extracted, unit_to)

    stage("Computing indicators")
    indicators <- extracted
    if (!is.null(heatwave)) {
        indicators <- calc_heatwave(indicators, excess = heatwave$excess,
                                    min_spell = min_spell, chunk = control$chunk)
    } else {
        if (!is.null(above) || !is.null(below)) {
            indicators <- calc_threshold_day(indicators, above = above, below = below,
                                             chunk = control$chunk)
        }
        if (!is.null(p)) {
            pct <- calc_percentile(extracted, p = p, exclude_below = exclude_below,
                                   yearly = control$yearly, baseline = baseline,
                                   chunk = control$chunk)
            indicators <- calc_percentile_day(indicators, pct, chunk = control$chunk)
        }
        if (spells) {
            indicators <- calc_spell(indicators, min_spell = min_spell,
                                     chunk = control$chunk)
            if (!is.null(p) && isTRUE(control$spell_excess)) {
                spell_pct <- calc_spell_percentile(indicators, p = p)
                indicators <- calc_spell_excess(indicators, spell_pct)
            }
        }
    }
    if (!is.null(boundaries)) {
        indicators <- aggregate_to_adm(indicators)
    }

    stage("Summarising over the reference windows")
    out <- summarise_by_interview(locations, indicators, window = window, by = by,
                                  min_coverage = control$min_coverage,
                                  chunk = control$chunk)
    out <- update_meta(out, preset = preset)
    if (isTRUE(control$keep_steps)) {
        return(list(locations = locations, extracted = extracted,
                    indicators = indicators, summary = out))
    }
    out
}

# ==== climate_indices() ===================================================== ----

#' Standardised precipitation indices before each interview, in one call
#'
#' Runs the chain from a survey and a precipitation raster to one row per
#' household and lag: the mean SPI (or SPEI) at each scale over the window
#' before the interview, and the number of months below each drought
#' threshold. Daily data are summed to months first. With `pet`, the SPEI
#' is computed from the water balance.
#'
#' The chain: [prepare_coord()], [georef_coord()], [read_climate()],
#' [aggregate_time()] when daily, [extract_by_coord()] (or cells and
#' [aggregate_to_adm()] with `boundaries`), [calc_std_index()],
#' [calc_std_threshold()] and [summarise_by_interview()].
#'
#' @param pre Monthly (or daily) precipitation: a file path, a `SpatRaster`
#'   or an extracted table.
#' @param pet Optional potential evapotranspiration, the same way; switches
#'   to the SPEI.
#' @param index `"spi"` or `"spei"`; by default SPEI when `pet` is given.
#' @param scale Accumulation scales in months; default `c(1, 3, 6)`.
#' @param below,above Thresholds on the index; default `below = c(-1, -1.5,
#'   -2)`.
#' @param window The reference window; default the month before the
#'   interview.
#' @param control Further options, see [indices_control()].
#' @inheritParams weather_extremes
#'
#' @return A `c4e_tbl` with one row per household and lag.
#'
#' @seealso [weather_extremes()], [list_presets()]
#' @export
#'
#' @examples
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' survey$interview <- as.Date(survey$interview)
#'
#' climate_indices(survey,
#'                 system.file("extdata", "pre_monthly.tif", package = "c4e"),
#'                 id = hhid, interview = interview, scale = 3)
climate_indices <- function(survey, pre, pet = NULL, lat = NULL, lon = NULL,
                            id = NULL, interview = NULL, preset = NULL,
                            index = NULL, scale = NULL, below = NULL, above = NULL,
                            window = NULL, boundaries = NULL,
                            control = indices_control()) {
    cols <- column_names(rlang::enquo(lat), rlang::enquo(lon), rlang::enquo(id),
                         rlang::enquo(interview))
    if (is_survey_list(survey)) {
        return(map_surveys(survey, \(one, name) {
            control$label <- name
            climate_indices(one, pre, pet = pet, lat = !!cols$lat, lon = !!cols$lon,
                            id = !!cols$id, interview = !!cols$interview,
                            preset = preset, index = index, scale = scale,
                            below = below, above = above, window = window,
                            boundaries = boundaries, control = control)
        }))
    }
    if (isFALSE(control$verbose)) {
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
    }
    env <- environment()
    stage <- function(msg) c4e_progress_step(msg, .envir = env)

    spec <- preset_spec(preset, "climate_indices")
    index <- index %||% spec$index %||% (if (!is.null(pet)) "spei" else "spi")
    scale <- scale %||% spec$scale %||% c(1, 3, 6)
    if (is.null(below) && is.null(above)) {
        below <- spec$below %||% c(-1, -1.5, -2)
    }
    window <- window %||% window_lag("1 month")

    locations <- survey_locations(survey, cols)
    points <- georef_coord(locations)
    to_monthly <- function(x) {
        x <- climate_input(x)
        if (inherits(x, "SpatRaster") && identical(raster_meta(x)$time_step, "day")) {
            x <- aggregate_time(x, "month")
        }
        x
    }
    pre <- to_monthly(pre)
    meta <- input_meta(pre)
    check_preset_data(spec, meta, preset)

    inform_spec(
        paste0("climate_indices", if (!is.null(preset)) paste0(" (", preset, ")")),
        meta,
        c(paste0(toupper(index), " at ", paste(scale, collapse = ", "), if (identical(as.numeric(scale), 1)) " month; " else " months; ",
                 describe_thresholds(above, below, NULL, NULL, NULL, NULL, FALSE)),
          paste("window:", describe_window(window))),
        locations)
    if (isTRUE(control$dry_run)) {
        inform_plan(c(
            paste0("extract precipitation", if (!is.null(pet)) " and evapotranspiration",
                   " at the survey locations"),
            paste0(toupper(index), " at scales ", paste(scale, collapse = ", ")),
            paste0("thresholds: ", describe_thresholds(above, below, NULL, NULL, NULL, NULL, FALSE)),
            paste0("summaries per household: ", describe_window(window))
        ))
        return(invisible(NULL))
    }

    stage("Extracting precipitation")
    extract_one <- function(x) {
        if (is_c4e_tbl(x)) return(x)
        if (!is.null(boundaries)) {
            return(aggregate_to_adm(extract_cell_by_poly(x, boundaries)))
        }
        extract_by_coord(x, points, chunk = control$chunk)
    }
    extracted <- extract_one(pre)
    pet_extracted <- if (!is.null(pet)) extract_one(to_monthly(pet))
    by <- NULL
    if (!is.null(boundaries)) {
        locations <- locations_in_divisions(locations, points, boundaries)
        by <- "ID_adm_div"
    }

    stage("Computing {toupper(index)}")
    indicators <- calc_std_index(extracted, scale = scale, index = index,
                                 pet = pet_extracted, chunk = control$chunk,
                                 .parallel = isTRUE(control$.parallel))
    indicators <- calc_std_threshold(indicators, above = above, below = below)

    stage("Summarising over the reference windows")
    out <- summarise_by_interview(locations, indicators, window = window, by = by,
                                  min_coverage = control$min_coverage,
                                  chunk = control$chunk)
    out <- update_meta(out, preset = preset)
    if (isTRUE(control$keep_steps)) {
        return(list(locations = locations, extracted = extracted,
                    indicators = indicators, summary = out))
    }
    out
}
