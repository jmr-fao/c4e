#' Standardised precipitation indices: SPI and SPEI
#'
#' Computes the Standardized Precipitation Index (SPI) or the Standardized
#' Precipitation-Evapotranspiration Index (SPEI) for every unit, at one or
#' more accumulation scales in months. Replaces [compute_spi()],
#' [compute_spei()] and [compute_water_balance()].
#'
#' The data must be monthly. Daily rasters are aggregated first with
#' [aggregate_time()], before extraction.
#'
#' For the SPEI, give potential evapotranspiration in `pet` (a table of the
#' same units and months): the water balance is precipitation minus its
#' absolute value, matched by unit and date, so ERA5's convention of negative
#' evaporation needs no change. Without `pet`, `x` is taken to be the water
#' balance already.
#'
#' Each series is fitted on its own with [SPEI::spi()] or [SPEI::spei()].
#'
#' @param x Monthly precipitation (or water balance), wide from
#'   `extract_*()` or long.
#' @param scale Accumulation periods in months, e.g. `c(1, 3, 6)`.
#' @param index `"spi"` or `"spei"`.
#' @param pet For the SPEI, monthly potential evapotranspiration for the same
#'   units and dates, in the same unit as `x`.
#' @param .parallel When `TRUE`, fit the series with `furrr`, following the
#'   user's `future::plan()`.
#' @inheritParams calc_threshold_day
#'
#' @return A long `c4e_tbl` with one column per scale, e.g. `spi_3`,
#'   registered with the index and scale.
#'
#' @seealso [calc_std_threshold()]
#' @family indicators
#' @export
#'
#' @examples
#' pre <- read_climate(
#'   system.file("extdata", "pre_monthly.tif", package = "c4e"))
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' extract_by_coord(pre, points) |>
#'   calc_std_index(scale = 3)
calc_std_index <- function(x, scale, index = c("spi", "spei"), pet = NULL,
                           id = NULL, label = NULL, chunk = "auto",
                           .parallel = FALSE) {
    started <- Sys.time()
    index <- rlang::arg_match(index)
    if (!is.numeric(scale) || any(scale < 1) || any(scale != round(scale))) {
        cli::cli_abort("{.arg scale} must be whole numbers of months, e.g. {.code c(1, 3)}.")
    }
    meta <- c4e_meta(x) %||% empty_meta()
    step <- meta$time_step %||% infer_time_step(indicator_frame(x, id)$dates)
    if (!identical(step, "month")) {
        shown <- step %||% "unknown"
        cli::cli_abort(c(
            "{.fn calc_std_index} needs monthly data; the input's time step is
             {.val {shown}}.",
            "i" = "Aggregate the raster to months before extracting, e.g.
                   {.code aggregate_time(pre, \"month\")}."
        ))
    }
    if (index == "spei") {
        if (is.null(pet)) {
            c4e_inform("Using {.arg x} as the climatic water balance (precipitation
                        minus evapotranspiration).")
        } else {
            check_meta_agrees(canonical_unit(c4e_meta(pet)$unit),
                              canonical_unit(meta$unit), "unit", field = "unit",
                              hint = "Convert one of the two with {.fn convert_unit}.")
            c4e_inform("Water balance: precipitation minus the absolute
                        evapotranspiration.")
        }
    } else if (!is.null(pet)) {
        cli::cli_abort("{.arg pet} is only used with {.code index = \"spei\"}.")
    }
    pet_frame <- if (!is.null(pet)) indicator_frame(pet, id)

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        values <- frame_matrix(frame, "value")
        if (!is.null(pet_frame)) {
            values <- values - abs(aligned_matrix(pet_frame, frame))
        }
        columns <- list()
        entries <- list()
        for (s in scale) {
            col <- paste0(index, "_", s)
            columns[[col]] <- spi_matrix(values, s, index, .parallel = .parallel)
            entries[[col]] <- new_indicator(
                "std", index = index, scale = s, base = "value",
                variable = frame$meta$variable, step = "month")
        }
        finish_frame(frame, columns, entries, list(
            transform = list(index = index, scale = scale,
                             base_variable = frame$meta$variable)))
    }

    run_indicator(x, compute, "calc_std_index",
                  args = list(scale = scale, index = index,
                              .parallel = if (.parallel) TRUE),
                  n_new = length(scale), id = id, label = label, chunk = chunk,
                  started = started)
}

#' Another table's values on this frame's units and dates
#' @noRd
aligned_matrix <- function(other, frame, col = "value", call = rlang::caller_env()) {
    by <- intersect(frame$id_cols, other$id_cols)
    unit_rows <- vctrs::vec_match(frame$ids[by], other$ids[by])
    date_cols <- match(frame$dates, other$dates)
    if (anyNA(unit_rows) || anyNA(date_cols)) {
        cli::cli_abort("{.arg pet} must cover every unit and month of {.arg x}.",
                       call = call)
    }
    frame_matrix(other, col)[unit_rows, date_cols, drop = FALSE]
}

#' Flag months beyond thresholds of a standardised index
#'
#' Flags, for every SPI or SPEI column registered by [calc_std_index()],
#' the months below or above each threshold, e.g. `spi3_blw_-1.5` for a
#' 3-month SPI below -1.5 (severe drought). The sign is kept in the name.
#' The flags are registered, so [calc_spell()] finds drought spells and the
#' window summaries count drought months. Replaces [extr_std_index()].
#'
#' @param x A long table from [calc_std_index()].
#' @param above,below Thresholds on the index, e.g. `below = c(-1, -1.5, -2)`.
#' @inheritParams calc_threshold_day
#'
#' @return `x` with one logical column per index column and threshold.
#'
#' @family indicators
#' @export
#'
#' @examples
#' pre <- read_climate(
#'   system.file("extdata", "pre_monthly.tif", package = "c4e"))
#' survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' extract_by_coord(pre, points) |>
#'   calc_std_index(scale = 3) |>
#'   calc_std_threshold(below = c(-1, -1.5, -2))
calc_std_threshold <- function(x, above = NULL, below = NULL, id = NULL,
                               label = NULL, chunk = "auto") {
    started <- Sys.time()
    if (is.null(above) && is.null(below)) {
        cli::cli_abort("Give {.arg above}, {.arg below} or both.")
    }
    meta <- c4e_meta(x) %||% empty_meta()
    std_cols <- names(purrr::keep(meta$indicators, \(entry) identical(entry$kind, "std")))
    std_cols <- intersect(std_cols, names(x))
    if (length(std_cols) == 0) {
        cli::cli_abort(c(
            "{.arg x} has no standardised index column.",
            "i" = "Compute one first with {.fn calc_std_index}."
        ))
    }

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        columns <- list()
        entries <- list()
        for (col in std_cols) {
            index_values <- frame_matrix(frame, col)
            source <- frame$meta$indicators[[col]]
            prefix <- paste0(source$index %||% "std", source$scale %||% "")
            for (direction in c("above", "below")) {
                thresholds <- if (direction == "above") above else below
                for (threshold in thresholds) {
                    name <- paste0(prefix, "_", direction_short(direction), "_", threshold)
                    columns[[name]] <- flag_threshold(index_values, threshold, direction)
                    entries[[name]] <- new_indicator(
                        "flag", base = col, direction = direction,
                        threshold = threshold, index = source$index,
                        scale = source$scale, step = frame$meta$time_step)
                }
            }
        }
        finish_frame(frame, columns, entries)
    }

    run_indicator(x, compute, "calc_std_threshold",
                  args = list(above = above, below = below),
                  n_new = length(std_cols) * (length(above) + length(below)),
                  id = id, label = label, chunk = chunk, started = started)
}
