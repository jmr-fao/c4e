# Indicators, parameters and controls for every cell of a raster (plan §13).
# The raster methods of the step functions and the two grid wrappers run the
# table steps on blocks of cells through grid_apply() (R/grid_engine.R).

# ==== Raster methods of the step functions ================================== ----

#' Indicators for every cell of a raster
#'
#' The step functions also take a `SpatRaster`: they then compute, for every
#' cell, what they compute for an extracted location, and return a raster.
#' The raster is read in blocks of rows, so stacks larger than memory can be
#' processed, and each block goes through the same code as extracted data:
#' a cell's numbers are those of the table path at that cell.
#'
#' * `calc_threshold_day()` counts, per `period` (year or month), the days
#'   beyond each threshold and sums their excess: layers such as
#'   `day_abv_30_sum_2021`.
#' * `calc_percentile()` gives each cell's percentiles by calendar month:
#'   layers such as `day_90p_07`.
#' * `calc_par()` gives each cell's statistics: layers such as `tmax_mean`.
#' * `calc_std_index()` gives the monthly SPI or SPEI: layers such as
#'   `spi_3_2021-07`.
#'
#' The result carries its dates, units and the indicator registry in tags
#' that survive writing a GeoTIFF; [extract_by_coord()] and
#' [extract_by_poly()] turn the extracted values back into the table the
#' table path gives, with its registry. For spells, percentile-based days and
#' heatwaves on a grid, use [grid_indicators()].
#'
#' @param x A `SpatRaster` of daily (or, for `calc_std_index()`, monthly)
#'   data with dates, ideally from [read_climate()].
#' @param above,below,unit,p,exclude_below,exclude_above,yearly,baseline,replace,fn,prefix,suffix,scale,index
#'   As for tables.
#' @param period For `calc_threshold_day()`: `"year"` or `"month"`, the
#'   periods counted. For `calc_par()`: as for tables.
#' @param min_coverage Share of a period's days that must have data.
#' @param pet For `calc_std_index()`: a raster of potential
#'   evapotranspiration with the same geometry, for the SPEI.
#' @param .parallel As for tables.
#' @param filename Optional GeoTIFF to write the result to.
#' @param overwrite Overwrite `filename` when it exists.
#' @param wopt Options for writing, as in [terra::writeRaster()], e.g.
#'   `list(datatype = "FLT4S", gdal = "COMPRESS=DEFLATE")`.
#' @param ... Not used.
#'
#' @return A `SpatRaster`, one layer per indicator (and period, month or
#'   date).
#'
#' @seealso [grid_indicators()], [grid_controls()]
#' @name grid_methods
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' hot <- calc_threshold_day(convert_unit(tmax, "C"), above = 30)
#' hot
NULL

#' @rdname grid_methods
#' @export
calc_threshold_day.SpatRaster <- function(x, above = NULL, below = NULL, unit = NULL,
                                          period = c("year", "month"),
                                          min_coverage = 0.8, filename = "",
                                          overwrite = FALSE, wopt = list(), ...) {
    rlang::check_dots_empty()
    period <- rlang::arg_match(period)
    compute <- function(tables) {
        calc_threshold_day(tables[[1]], above = above, below = below, unit = unit) |>
            summarise_by_period(period, min_coverage = min_coverage)
    }
    args <- list(above = above, below = below, unit = unit, period = period)
    if (grid_fast()) {
        fast <- fast_threshold_grid(x, compute, period, min_coverage, "calc_threshold_day",
                                    args, filename, overwrite, wopt)
        if (!is.null(fast)) return(fast)
    }
    grid_apply(list(x = x), compute, "calc_threshold_day", args,
               filename = filename, overwrite = overwrite, wopt = wopt,
               rows_per_block = grid_rows(), label = "Days beyond thresholds")
}

#' Whether the tapp() fast path may be used; options(c4e.grid_fast = FALSE)
#' forces the block engine
#' @noRd
grid_fast <- function() {
    !isFALSE(getOption("c4e.grid_fast"))
}

#' @rdname grid_methods
#' @export
calc_percentile.SpatRaster <- function(x, p, exclude_below = NULL, exclude_above = NULL,
                                       yearly = FALSE, baseline = NULL,
                                       replace = NA_real_, filename = "",
                                       overwrite = FALSE, wopt = list(), ...) {
    rlang::check_dots_empty()
    compute <- function(tables) {
        calc_percentile(tables[[1]], p = p, exclude_below = exclude_below,
                        exclude_above = exclude_above, yearly = yearly,
                        baseline = baseline, replace = replace)
    }
    grid_apply(list(x = x), compute, "calc_percentile",
               list(p = p, exclude_below = exclude_below, exclude_above = exclude_above,
                    yearly = yearly),
               filename = filename, overwrite = overwrite, wopt = wopt,
               rows_per_block = grid_rows(), label = "Percentiles")
}

#' @rdname grid_methods
#' @export
calc_par.SpatRaster <- function(x, fn, period = NULL, min_coverage = 0.8, prefix = NULL,
                                suffix = NULL, filename = "", overwrite = FALSE,
                                wopt = list(), ...) {
    rlang::check_dots_empty()
    fns <- as_function_list(fn, rlang::enexpr(fn))
    # announced once here; the blocks run quietly
    suppressWarnings(ratio_shift(raster_meta(x), ratio_statistics(fns)))
    compute <- function(tables) {
        calc_par(tables[[1]], fn = fns, period = period, min_coverage = min_coverage,
                 prefix = prefix, suffix = suffix)
    }
    grid_apply(list(x = x), compute, "calc_par",
               list(fn = names(fns), period = period, prefix = prefix, suffix = suffix),
               filename = filename, overwrite = overwrite, wopt = wopt,
               rows_per_block = grid_rows(), label = "Parameters")
}

#' @rdname grid_methods
#' @export
calc_std_index.SpatRaster <- function(x, scale, index = c("spi", "spei"), pet = NULL,
                                      .parallel = FALSE, filename = "",
                                      overwrite = FALSE, wopt = list(), ...) {
    rlang::check_dots_empty()
    index <- rlang::arg_match(index)
    if (!is.null(pet) && !inherits(pet, "SpatRaster")) {
        cli::cli_abort("{.arg pet} must be a {.cls SpatRaster} like {.arg x}.")
    }
    rasters <- purrr::compact(list(pre = x, pet = pet))
    compute <- function(tables) {
        calc_std_index(tables$pre, scale = scale, index = index, pet = tables$pet,
                       .parallel = .parallel)
    }
    grid_apply(rasters, compute, "calc_std_index",
               list(scale = scale, index = index),
               filename = filename, overwrite = overwrite, wopt = wopt,
               rows_per_block = grid_rows(), label = "Standardised index")
}

#' Days beyond fixed thresholds and their excess per period with terra's
#' tapp()
#'
#' The fast path of the grid (inst/bench/results-grid.md): the same layers,
#' names and registry as the block engine, which are taken from the table
#' steps run on one cell, and the same rules: a period with no value sums to
#' 0, a period with fewer days than `min_coverage` asks is missing, and a
#' cell with no data at all stays empty. Returns NULL when the indicators are
#' not all sums of fixed-threshold flags or excess.
#' @noRd
fast_threshold_grid <- function(x, compute, period, min_coverage, grid_fn, grid_args,
                                filename, overwrite, wopt, call = rlang::caller_env()) {
    sample <- sample_result(list(x = x), compute)
    if (is.null(sample)) {
        cli::cli_abort("No cell of the raster has data.", call = call)
    }
    meta <- raster_meta(x)
    layout <- grid_layout(sample, meta)
    simple <- vapply(layout$entries, \(entry) {
        identical(entry$kind, "agg") && identical(entry$stat, "sum") &&
            isTRUE(entry$of %in% c("flag", "excess")) && is.numeric(entry$threshold)
    }, logical(1))
    if (length(simple) == 0 || !all(simple) || layout$slice_type != "date") {
        return(NULL)
    }
    if (nzchar(filename) && file.exists(filename) && !isTRUE(overwrite)) {
        cli::cli_abort("{.file {filename}} exists; use {.code overwrite = TRUE}.",
                       call = call)
    }

    starts <- lubridate::floor_date(layer_dates(x), period)
    if (!setequal(unique(starts), layout$slices)) {
        return(NULL)
    }
    index <- factor(format(starts), levels = format(layout$slices))
    present <- terra::tapp(!is.na(x), index, "sum")
    ends <- lubridate::ceiling_date(layout$slices, period, change_on_boundary = TRUE) - 1L
    expected <- expected_count(layout$slices - 1L, ends, meta$time_step %||% "day")
    too_few <- present < (min_coverage * expected)
    has_data <- sum(present) > 0

    layers <- lapply(layout$cols, \(col) {
        entry <- layout$entries[[col]]
        threshold <- entry$threshold
        above <- identical(entry$direction, "above")
        beyond <- if (above) x > threshold else x < threshold
        values <- if (identical(entry$of, "flag")) {
            beyond
        } else {
            terra::ifel(beyond, if (above) x - threshold else threshold - x, 0)
        }
        sums <- terra::subst(terra::tapp(values, index, "sum", na.rm = TRUE), NA, 0)
        sums <- terra::mask(sums, has_data, maskvalues = 0)
        terra::mask(sums, too_few, maskvalues = 1)
    })
    out <- describe_grid(do.call(c, layers), layout, meta, grid_fn, grid_args)
    if (nzchar(filename)) {
        out <- do.call(terra::writeRaster,
                       c(list(out, filename = filename, overwrite = TRUE), wopt))
    }
    out
}

#' The table steps run on the first cell with data, for the layer names and
#' registry of a grid result; NULL when no cell has data
#' @noRd
sample_result <- function(rasters, compute) {
    metas <- lapply(rasters, raster_meta)
    columns <- lapply(rasters, block_columns)
    for (r in rasters) terra::readStart(r)
    on.exit(for (r in rasters) terra::readStop(r), add = TRUE)
    for (row in seq_len(terra::nrow(rasters[[1]]))) {
        values <- lapply(rasters, \(r) terra::readValues(r, row = row, nrows = 1, mat = TRUE))
        with_data <- Reduce(`&`, lapply(values, \(v) rowSums(!is.na(v)) > 0))
        if (any(with_data)) {
            k <- which(with_data)[1]
            tables <- Map(\(v, cols, meta) block_table(v[k, , drop = FALSE], 1L, cols, meta),
                          values, columns, metas)
            old <- options(c4e.verbose = FALSE)
            on.exit(options(old), add = TRUE)
            return(suppressWarnings(compute(tables)))
        }
    }
    NULL
}

#' Raster rows per block when forced with options(c4e.grid_rows = n)
#' @noRd
grid_rows <- function() {
    rows <- getOption("c4e.grid_rows")
    if (is.null(rows)) NULL else max(1L, as.integer(rows))
}

# ==== grid_indicators() ===================================================== ----

#' Weather extremes for every cell of a raster, in one call
#'
#' The grid counterpart of [weather_extremes()]: the same presets and
#' arguments, computed for every cell and summarised per year or month
#' instead of over the window before an interview. The result is a raster
#' with one layer per indicator and period, e.g. `day_abv_30_sum_2021` or
#' `spell_abv_30_max_2021`, for maps, panels of grid cells or divisions, or
#' extraction at many surveys at once.
#'
#' The raster is processed in blocks of rows, each block going through the
#' same steps as [weather_extremes()] (thresholds or percentiles, spells, a
#' summary per period with [summarise_by_period()]); with `filename` the
#' result is written to a GeoTIFF, so country-scale daily stacks need not fit
#' in memory. The indicator registry is kept in the file's tags:
#' [extract_by_coord()] on the result gives the table, registry included,
#' that the table path gives.
#'
#' @param climate A daily raster: a file path or a `SpatRaster`.
#' @param period `"year"` or `"month"`.
#' @param filename Optional GeoTIFF to write the result to.
#' @param overwrite Overwrite `filename` when it exists.
#' @param wopt Options for writing, as in [terra::writeRaster()].
#' @param control Further options, see [extremes_control()]; its
#'   `min_coverage` applies to each period.
#' @inheritParams weather_extremes
#'
#' @return A `SpatRaster`, one layer per indicator and period; with
#'   `dry_run`, `NULL`.
#'
#' @seealso [weather_extremes()], [grid_controls()], [grid_methods]
#' @export
#'
#' @examples
#' hot <- grid_indicators(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"),
#'   preset = "heat")
#' names(hot)
grid_indicators <- function(climate, preset = NULL, above = NULL, below = NULL, p = NULL,
                            spells = TRUE, min_spell = NULL, period = c("year", "month"),
                            baseline = NULL, unit = NULL, filename = "",
                            overwrite = FALSE, wopt = list(),
                            control = extremes_control()) {
    period <- rlang::arg_match(period)
    if (isFALSE(control$verbose)) {
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
    }
    s <- extremes_spec(preset, above, below, p, min_spell)
    raster <- grid_raster(climate)
    meta <- raster_meta(raster)
    check_preset_data(s$spec, meta, preset)
    unit_to <- target_unit(meta, s$spec, c(s$above, s$below), unit)
    exclude_below <- extremes_exclude_below(control, s$spec, s$p, meta)
    if (!is.null(unit_to) && !identical(canonical_unit(meta$unit), canonical_unit(unit_to))) {
        from <- meta$unit
        c4e_inform("Converting {.val {from}} to {.val {unit_to}} to read the thresholds.")
    }

    thresholds <- describe_thresholds(s$above, s$below, s$p, unit_to %||% meta$unit,
                                      s$heatwave, s$min_spell, spells)
    series <- series_label(list(variable = meta$variable %||% "values",
                                unit = meta$unit, time_step = meta$time_step))
    n_cells <- terra::ncell(raster)
    n_layers <- terra::nlyr(raster)
    title <- paste0("grid_indicators", if (!is.null(preset)) paste0(" (", preset, ")"))
    c4e_inform(c("i" = "{title}: {series}",
                 " " = "{thresholds}",
                 " " = "per {period}; {n_cells} cells, {n_layers} layers"))
    if (isTRUE(control$dry_run)) {
        inform_plan(c(paste0("read ", n_layers, " layers of ", n_cells, " cells in blocks"),
                      if (!is.null(unit_to)) paste0("convert to ", unit_to),
                      paste0("indicators: ", thresholds),
                      paste0("summaries per ", period),
                      if (nzchar(filename)) paste0("write ", filename)))
        return(invisible(NULL))
    }

    block_control <- control
    block_control$chunk <- "auto"
    compute <- function(tables) {
        x <- to_unit(tables[[1]], unit_to)
        compute_extremes(x, s, spells, exclude_below, baseline, block_control) |>
            summarise_by_period(period, min_coverage = control$min_coverage)
    }
    args <- list(preset = preset, above = s$above, below = s$below, p = s$p,
                 spells = spells, min_spell = s$min_spell, period = period,
                 unit = unit_to)
    if (grid_fast() && !spells && is.null(s$p) && is.null(s$heatwave)) {
        converted <- if (is.null(unit_to)) raster else suppressMessages(convert_unit(raster, unit_to))
        fast <- fast_threshold_grid(converted, compute, period, control$min_coverage,
                                    "grid_indicators", args, filename, overwrite, wopt)
        if (!is.null(fast)) return(fast)
    }
    rows <- if (is.numeric(control$chunk)) control$chunk else grid_rows()
    grid_apply(list(climate = raster), compute, "grid_indicators", args,
               filename = filename, overwrite = overwrite, wopt = wopt,
               rows_per_block = rows, label = "Grid indicators")
}

#' A raster for the grid wrappers: a path or SpatRaster, read with its context
#' @noRd
grid_raster <- function(x, variable = NULL, call = rlang::caller_env()) {
    if (is_c4e_tbl(x) || is.data.frame(x)) {
        cli::cli_abort(c("The grid wrappers need a raster, not a table.",
                         "i" = "For extracted data, use {.fn weather_extremes} or the
                                step functions."), call = call)
    }
    if (inherits(x, "SpatRaster") && !is.null(stored_raster_meta(x)$variable) &&
        is.null(variable)) {
        return(x)
    }
    suppressMessages(climate_input(x, variable = variable, call = call))
}

# ==== grid_controls() ======================================================= ----

#' Spatial controls for every cell of a raster, in one call
#'
#' The grid counterpart of [static_controls()] and the normals of
#' [time_varying_controls()]: population density of the surrounding cells,
#' climate normals and other layers, as one raster.
#'
#' * With `pop`, `pop_density_<r>km` is the population within each radius
#'   divided by the land area within it (cells where `pop` is missing count
#'   for neither), in people per square kilometre. A radius of 0 gives the
#'   cell's own density, `pop_density`. On longitude/latitude rasters the
#'   circle is measured in kilometres at the raster's mean latitude.
#' * With `climate`, a named list of rasters, `<name>_<stat>` are the
#'   statistics over the last `years` years of each series, computed with
#'   [calc_par()]; a coefficient of variation of temperatures is computed on
#'   kelvin.
#' * With `layers`, a named list of single-layer rasters, each is added, and
#'   aggregated by `fact` when given: averaged, summed or by majority,
#'   following its kind (see [static_controls()]).
#'
#' Rasters on different grids are resampled onto the first one (bilinear
#' for continuous layers, nearest for categorical ones, sums for counts),
#' with a message.
#'
#' @param pop A population (count) raster with one layer.
#' @param radius_m Radii in metres for the population density.
#' @param climate Optional named list of climate rasters (paths or
#'   `SpatRaster`s), e.g. `list(pre = chirps)`.
#' @param years Number of years, counted back from the end of each series,
#'   for the normals.
#' @param stats Statistics of the normals: any of `"mean"`, `"sd"`, `"cv"`,
#'   `"min"`, `"max"`, `"median"`, `"sum"`.
#' @param layers Optional named list of other single-layer rasters.
#' @param kind Optional named character vector of layer kinds.
#' @param fact Optional aggregation factor for `layers`, as in
#'   [terra::aggregate()].
#' @inheritParams grid_indicators
#' @param control Further options, see [controls_control()].
#'
#' @return A `SpatRaster` with one layer per control; with `dry_run`, `NULL`.
#'
#' @seealso [static_controls()], [time_varying_controls()], [grid_indicators()]
#' @export
#'
#' @examples
#' template <- terra::rast(system.file("extdata", "tmax_daily.tif",
#'                                     package = "c4e"))[[1]]
#' pop <- terra::rast(template, vals = seq(100, 3600, by = 100))
#' grid_controls(pop = pop, radius_m = c(0, 50000))
grid_controls <- function(pop = NULL, radius_m = c(5000, 10000), climate = NULL,
                          years = 30, stats = c("mean", "sd", "cv"), layers = NULL,
                          kind = NULL, fact = NULL, filename = "", overwrite = FALSE,
                          wopt = list(), control = controls_control()) {
    if (isFALSE(control$verbose)) {
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
    }
    if (is.null(pop) && is.null(climate) && is.null(layers)) {
        cli::cli_abort("Give {.arg pop}, {.arg climate} or {.arg layers}.")
    }
    if (nzchar(filename) && file.exists(filename) && !isTRUE(overwrite)) {
        cli::cli_abort("{.file {filename}} exists; use {.code overwrite = TRUE}.")
    }
    fns <- stats::setNames(purrr::map(stats, normal_function), stats)
    c4e_inform(c("i" = "grid_controls",
                 " " = paste(c(if (!is.null(pop)) paste0("population density within ",
                                                         paste(radius_m / 1000, collapse = ", "),
                                                         " km"),
                               if (!is.null(climate)) paste0("normals of ",
                                                             paste(names(climate), collapse = ", ")),
                               if (!is.null(layers)) paste0("layers ",
                                                            paste(names(layers), collapse = ", "))),
                             collapse = "; ")))
    if (isTRUE(control$dry_run)) {
        inform_plan(c(if (!is.null(pop)) paste0(length(radius_m), " density radii"),
                      if (!is.null(climate)) paste0(length(climate), " climate series"),
                      if (!is.null(layers)) paste0(length(layers), " other layers")))
        return(invisible(NULL))
    }

    parts <- list()
    part_kinds <- character()
    entries <- list()
    if (!is.null(pop)) {
        pop <- grid_raster(pop, variable = "pop")
        if (terra::nlyr(pop) != 1) {
            cli::cli_abort("{.arg pop} must have one layer; pick a year with
                            {.code pop[[k]]}.")
        }
        for (radius in radius_m) {
            column <- paste0("pop_density", buffer_suffix(radius))
            parts[[column]] <- population_density(pop, radius)
            part_kinds[[column]] <- "continuous"
            entries[[column]] <- control_entry("pop", "count", radius, stat = "density",
                                               unit = "per km2")
        }
    }
    for (name in names(climate)) {
        series <- grid_raster(climate[[name]], variable = name)
        window <- normals_window(series, name, years)
        normals <- calc_par(window, fn = fns, prefix = name)
        info <- read_grid_meta(normals)
        for (i in seq_len(terra::nlyr(normals))) {
            column <- names(normals)[i]
            parts[[column]] <- normals[[i]]
            part_kinds[[column]] <- "continuous"
            entry <- info$entries[[column]]
            entry$years <- years
            entries[[column]] <- entry
        }
    }
    for (name in names(layers)) {
        layer <- grid_raster(layers[[name]], variable = name)
        layer_type <- layer_kind(layer, name, kind)
        if (!is.null(fact)) {
            layer <- terra::aggregate(layer, fact = fact,
                                      fun = switch(layer_type, categorical = "modal",
                                                   count = "sum", "mean"),
                                      na.rm = TRUE)
        }
        parts[[name]] <- layer
        part_kinds[[name]] <- layer_type
        entries[[name]] <- control_entry(name, layer_type, 0)
    }

    template <- parts[[1]]
    resampled <- character()
    for (name in names(parts)[-1]) {
        if (!terra::compareGeom(template, parts[[name]], stopOnError = FALSE)) {
            parts[[name]] <- terra::resample(
                parts[[name]], template,
                method = switch(part_kinds[[name]], categorical = "near",
                                count = "sum", "bilinear"))
            resampled <- c(resampled, name)
        }
    }
    if (length(resampled) > 0) {
        c4e_inform("Resampled {.field {resampled}} onto the grid of {.field {names(parts)[1]}}.")
    }
    out <- do.call(c, unname(parts))
    names(out) <- names(parts)
    layout <- list(cols = names(parts), slice = NULL, slice_type = "none", slices = NULL,
                   names = names(parts), layer_col = names(parts), entries = entries,
                   time_step = NULL, variable = NULL, unit = NULL)
    out <- describe_grid(out, layout, list(), "grid_controls",
                         list(radius_m = if (!is.null(pop)) radius_m,
                              years = if (!is.null(climate)) years,
                              stats = if (!is.null(climate)) stats, fact = fact))
    if (nzchar(filename)) {
        out <- do.call(terra::writeRaster,
                       c(list(out, filename = filename, overwrite = TRUE), wopt))
    }
    out
}

#' People per square kilometre within a radius of each cell
#' @noRd
population_density <- function(pop, radius) {
    area <- terra::mask(terra::cellSize(pop, unit = "km"), pop)
    if (radius <= 0) {
        density <- pop / area
    } else {
        w <- circle_window(pop, radius)
        density <- terra::focal(pop, w = w, fun = "sum", na.rm = TRUE) /
            terra::focal(area, w = w, fun = "sum", na.rm = TRUE)
        density <- terra::mask(density, pop)
    }
    names(density) <- paste0("pop_density", buffer_suffix(radius))
    density
}

#' A circular focal window of a radius in metres, in cells
#'
#' On longitude/latitude rasters the cell size in kilometres is taken at the
#' raster's mean latitude.
#' @noRd
circle_window <- function(r, radius_m) {
    if (terra::is.lonlat(r)) {
        extent <- as.vector(terra::ext(r))
        latitude <- mean(extent[c("ymin", "ymax")])
        dx <- terra::xres(r) * 111.32 * cos(latitude * pi / 180)
        dy <- terra::yres(r) * 111.32
    } else {
        metres <- terra::linearUnits(r)
        if (!isTRUE(metres > 0)) metres <- 1
        dx <- terra::xres(r) * metres / 1000
        dy <- terra::yres(r) * metres / 1000
    }
    radius <- radius_m / 1000
    nx <- floor(radius / dx)
    ny <- floor(radius / dy)
    x <- outer(rep(1, 2 * ny + 1), (-nx:nx) * dx)
    y <- outer((-ny:ny) * dy, rep(1, 2 * nx + 1))
    w <- (x^2 + y^2 <= radius^2) * 1
    w
}

#' The last `years` years of a series, with a message when it is shorter
#' @noRd
normals_window <- function(series, name, years) {
    dates <- layer_dates(series)
    last <- max(dates, na.rm = TRUE)
    last_year <- as.integer(format(last, "%Y"))
    from <- as.Date(paste0(last_year - years + 1, "-01-01"))
    first_year <- as.integer(format(min(dates, na.rm = TRUE), "%Y"))
    if (first_year > last_year - years + 1) {
        c4e_inform("{.field {name}} covers {first_year} to {last_year}, fewer than the
                    {years} years asked for.")
    }
    select_by_dates(series, from = from, to = last)
}
