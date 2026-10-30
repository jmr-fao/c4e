# Compare c4e with climatic4economist (v1) on the same data
#
# Each package runs its own chain, from reading the survey and the rasters to
# the summaries over the interview windows, and the outputs are matched
# location by location (v1 numbers locations by sorted coordinates, c4e names
# them by their coordinates, so the two are joined on the coordinates).
#
# The report lists, for every indicator, how many values were compared, how
# many agree, and the largest difference, with the time each package took.
# It holds no household rows and no coordinates, so it can be shared.
#
# Usage, from the package root:
#   Rscript dev/compare/compare-v1.R                    # the bundled fixtures
#   Rscript dev/compare/compare-v1.R path/to/config.R   # your data
# A config file sets `config <- list(...)` with the fields of `defaults` below
# (see dev/compare/config-example.R). Reports go to `out_dir`; the default,
# dev/compare/out/, is ignored by git. The data are only read.

# ==== Settings ============================================================ ----

defaults <- list(
    name = "bundled fixtures",
    # the survey: a .dta, .csv or .rds file with one row per household
    survey = system.file("extdata", "survey.csv", package = "c4e"),
    id = "hhid", lat = "lat", lon = "lon", interview = "interview",
    # a daily raster (temperature or precipitation) and the unit to compare in
    daily = system.file("extdata", "tmax_daily.tif", package = "c4e"),
    daily_to_unit = "C",              # NULL keeps the raster's unit; "C" from K, "mm" from m
    from = NULL, to = NULL,           # optional dates to keep, e.g. "1991-01-01"
    above = c(30, 35), below = NULL,  # thresholds in daily_to_unit
    min_spell = 2,
    p = c(0.1, 0.9), exclude_below = NULL,   # percentiles; exclude_below for wet days
    heatwave = TRUE,                  # WMO heatwave, temperature only
    interval = "1 year", n_lags = 1,
    # a monthly precipitation raster for SPI (NULL to skip)
    monthly = system.file("extdata", "pre_monthly.tif", package = "c4e"),
    scale = c(1, 3),
    # administrative divisions for the cell extraction (NULL to skip)
    boundaries = system.file("extdata", "adm_div.gpkg", package = "c4e"),
    # where the two packages come from; a folder is loaded with pkgload
    c4e_source = ".",
    v1_source = "../climatic4economist",
    tolerance = 1e-8,
    out_dir = "dev/compare/out"
)

args <- commandArgs(trailingOnly = TRUE)
config <- defaults
if (length(args) > 0) {
    env <- new.env()
    sys.source(args[1], envir = env)
    # `[<-` keeps fields set to NULL (modifyList() would drop them, so
    # `monthly = NULL` would fall back to the fixtures)
    config[names(env$config)] <- env$config
}

load_package <- function(source, name) {
    if (!is.null(source) && dir.exists(source)) {
        pkgload::load_all(source, export_all = FALSE, attach = FALSE, quiet = TRUE)
        paste(name, "from", normalizePath(source, winslash = "/"),
              paste0("(", as.character(utils::packageVersion(name)), ")"))
    } else {
        loadNamespace(name)
        paste(name, as.character(utils::packageVersion(name)), "(installed)")
    }
}
sources <- c(c4e = load_package(config$c4e_source, "c4e"),
             v1 = load_package(config$v1_source, "climatic4economist"))
options(c4e.verbose = FALSE)

# ==== Helpers ============================================================= ----

timings <- list()
timed <- function(step, side, expr) {
    started <- Sys.time()
    value <- suppressMessages(suppressWarnings(expr))
    timings[[length(timings) + 1]] <<- data.frame(
        step = step, side = side,
        secs = as.numeric(difftime(Sys.time(), started, units = "secs")))
    value
}

results <- list()
#' Match `a` (c4e) and `b` (v1) on `keys` and compare each column of `cols`
compare <- function(step, a, b, keys, cols, note = "") {
    a <- tibble::as_tibble(a)
    b <- tibble::as_tibble(b)
    cols <- intersect(cols, intersect(names(a), names(b)))
    joined <- dplyr::full_join(a[c(keys, cols)], b[c(keys, cols)], by = keys,
                               suffix = c(".c4e", ".v1"))
    for (col in cols) {
        x <- joined[[paste0(col, ".c4e")]]
        y <- joined[[paste0(col, ".v1")]]
        if (is.logical(x) || is.logical(y)) {
            x <- as.numeric(x)
            y <- as.numeric(y)
        }
        both <- !is.na(x) & !is.na(y)
        diff <- abs(x[both] - y[both])
        results[[length(results) + 1]] <<- data.frame(
            step = step, column = col, compared = sum(both),
            agree = sum(diff <= config$tolerance * pmax(1, abs(y[both]))),
            max_diff = if (any(both)) signif(max(diff), 3) else NA_real_,
            na_c4e_only = sum(is.na(x) & !is.na(y)),
            na_v1_only = sum(!is.na(x) & is.na(y)),
            note = note)
    }
    invisible(joined)
}

read_survey <- function(path) {
    data <- switch(tolower(tools::file_ext(path)),
                   dta = haven::zap_labels(haven::read_dta(path)),
                   csv = utils::read.csv(path),
                   rds = readRDS(path),
                   stop("The survey must be a .dta, .csv or .rds file."))
    data <- tibble::as_tibble(data)
    keep <- unlist(config[c("id", "lat", "lon", "interview")])
    missing <- setdiff(keep, names(data))
    if (length(missing) > 0) stop("Survey columns not found: ", toString(missing))
    data <- data[keep]
    names(data) <- c("hhid", "lat", "lon", "interview")
    data$hhid <- as.character(data$hhid)
    data$interview <- as.Date(data$interview)
    data[!is.na(data$lat) & !is.na(data$lon), ]
}

# v1 reads a raster with terra and names the layers by their dates
v1_raster <- function(path) {
    raster <- terra::rast(path)
    dates <- as.Date(terra::time(raster))
    if (anyNA(dates)) stop("The raster ", path, " has no dates in terra::time().")
    names(raster) <- as.character(dates)
    raster
}

keep_dates <- function(raster) {
    dates <- as.Date(terra::time(raster))
    keep <- rep(TRUE, length(dates))
    if (!is.null(config$from)) keep <- keep & dates >= as.Date(config$from)
    if (!is.null(config$to)) keep <- keep & dates <= as.Date(config$to)
    raster[[which(keep)]]
}

# date columns: c4e writes 2021-01-01, v1 writes X2021_01_01
date_columns <- function(x) grep("^X?\\d{4}[-_]\\d{2}[-_]\\d{2}$", names(x), value = TRUE)
label_to_date <- function(x) as.Date(gsub("_", "-", sub("^X", "", x)))

# v1 users convert by hand on the wide table
v1_convert <- function(wide, from, to) {
    if (is.null(to) || identical(from, to)) return(wide)
    dates <- names(wide) %in% date_columns(wide)
    if (from == "K" && to == "C") {
        wide[dates] <- wide[dates] - 273.15
    } else if (from == "m" && to == "mm") {
        wide[dates] <- wide[dates] * 1000
    } else {
        stop("The v1 side converts only K to C and m to mm; set daily_to_unit = NULL.")
    }
    wide
}

wide_to_long <- function(wide, value_name) {
    tibble::as_tibble(wide)[c("ID", date_columns(wide))] |>
        tidyr::pivot_longer(-ID, names_to = "date", values_to = value_name) |>
        dplyr::mutate(date = label_to_date(date))
}

# ==== Survey and locations ================================================ ----

survey <- read_survey(config$survey)

coord_v1 <- timed("locations", "v1", {
    climatic4economist::prepare_coord(survey, lat_var = lat, lon_var = lon)
})
points_v1 <- timed("locations", "v1",
                   climatic4economist::georef_coord(coord_v1, geom = c("lon", "lat"),
                                                    crs = "EPSG:4326"))
coord <- timed("locations", "c4e",
               c4e::prepare_coord(survey, lat_var = lat, lon_var = lon,
                                  id = hhid, interview = interview))
points <- timed("locations", "c4e", c4e::georef_coord(coord))

# v1 location numbers -> c4e identifiers, through the coordinates
id_map <- dplyr::distinct(tibble::as_tibble(coord_v1)[c("ID", "lat", "lon")]) |>
    dplyr::inner_join(dplyr::distinct(tibble::as_tibble(coord)[c("ID", "lat", "lon")]),
                      by = c("lat", "lon"), suffix = c(".v1", ".c4e"))
stopifnot(nrow(id_map) == dplyr::n_distinct(coord_v1$ID))
to_c4e_id <- function(x) {
    x <- tibble::as_tibble(x)
    x$ID <- id_map$ID.c4e[match(x$ID, id_map$ID.v1)]
    x
}

# ==== Daily indicators ==================================================== ----

daily_c4e <- timed("read daily", "c4e", keep_dates(c4e::read_climate(config$daily)))
daily_v1 <- timed("read daily", "v1", keep_dates(v1_raster(config$daily)))
unit_from <- terra::units(daily_c4e)[1]
unit <- config$daily_to_unit %||% unit_from

wide <- timed("extract", "c4e", {
    out <- c4e::extract_by_coord(daily_c4e, points)
    if (!is.null(config$daily_to_unit)) out <- c4e::convert_unit(out, config$daily_to_unit)
    out
})
wide_v1 <- timed("extract", "v1", {
    climatic4economist::extract_by_coord(daily_v1, points_v1) |>
        v1_convert(unit_from, config$daily_to_unit)
})
compare("extraction", wide_to_long(wide, "value"),
        wide_to_long(to_c4e_id(wide_v1), "value"), c("ID", "date"), "value")

days <- timed("thresholds", "c4e", {
    c4e::calc_threshold_day(wide, above = config$above, below = config$below)
})
days_v1 <- timed("thresholds", "v1", {
    climatic4economist::find_extr_abs_day(wide_v1, u_thresh = config$above,
                                          l_thresh = config$below, unit = unit)
})
flag_cols <- grep("_(abv|blw)_", names(days), value = TRUE)
compare("thresholds", days, to_c4e_id(days_v1), c("ID", "date"), flag_cols)

spells <- timed("spells", "c4e", c4e::calc_spell(days, min_spell = config$min_spell))
spells_v1 <- timed("spells", "v1",
                   climatic4economist::find_spell(days_v1, min_spell = config$min_spell))
spell_cols <- grep("^spell_", names(spells), value = TRUE)
compare("spells", spells, to_c4e_id(spells_v1), c("ID", "date"), spell_cols)

if (length(config$p) > 0) {
    pct <- timed("percentiles", "c4e", {
        c4e::calc_percentile(wide, p = config$p, exclude_below = config$exclude_below)
    })
    pct_v1 <- timed("percentiles", "v1", {
        climatic4economist::calc_pct_day(wide_v1, p = config$p,
                                         l_thresh = config$exclude_below)
    })
    pct_cols <- grep("^day_\\d+p$", names(pct), value = TRUE)
    compare("monthly percentiles", pct, to_c4e_id(pct_v1), c("ID", "month"), pct_cols)

    rel <- timed("percentile days", "c4e", c4e::calc_percentile_day(wide, pct))
    upper <- config$p[config$p >= 0.5]
    lower <- config$p[config$p < 0.5]
    rel_v1 <- timed("percentile days", "v1", {
        out <- NULL
        if (length(upper) > 0) {
            out <- climatic4economist::find_extr_rel_day(
                wide_v1, u_thresh = climatic4economist::calc_pct_day(
                    wide_v1, p = upper, l_thresh = config$exclude_below), unit = unit)
        }
        if (length(lower) > 0) {
            low <- climatic4economist::find_extr_rel_day(
                wide_v1, l_thresh = climatic4economist::calc_pct_day(
                    wide_v1, p = lower, l_thresh = config$exclude_below), unit = unit)
            out <- if (is.null(out)) low else
                dplyr::left_join(tibble::as_tibble(out),
                                 dplyr::select(tibble::as_tibble(low), -value),
                                 by = c("ID", "date"))
        }
        out
    })
    rel_cols <- grep("_(abv|blw)_\\d+p$", names(rel), value = TRUE)
    compare("percentile days", rel, to_c4e_id(rel_v1), c("ID", "date"), rel_cols)
}

is_temperature <- unit %in% c("C", "K", "F")
if (isTRUE(config$heatwave) && identical(unit, "C")) {
    hw <- timed("heatwave", "c4e", c4e::calc_heatwave(wide, excess = 5, min_spell = 2))
    hw_v1 <- timed("heatwave", "v1",
                   climatic4economist::find_wmo_heatwave(wide_v1, excess = 5, min_spell = 2))
    compare("WMO heatwave", hw, to_c4e_id(hw_v1), c("ID", "date"), "spell_wmo")
}

# ==== Summaries over the interview windows ================================ ----

summary <- timed("interview windows", "c4e", {
    c4e::summarise_by_interview(coord, spells, interval = config$interval,
                                n_lags = config$n_lags)
})
summary_all <- timed("interview windows", "c4e", {
    c4e::summarise_by_interview(coord, spells, interval = config$interval,
                                n_lags = config$n_lags, min_coverage = 0)
})
survey_v1 <- to_c4e_id(coord_v1)
days_ind_v1 <- to_c4e_id(days_v1)
spells_ind_v1 <- to_c4e_id(spells_v1)
days_sum_v1 <- timed("interview windows", "v1", {
    climatic4economist::extr_day_by_interview(survey_v1, days_ind_v1, by = ID, id = hhid,
                                              interview = interview,
                                              interval = config$interval,
                                              n_lags = config$n_lags)
})
spells_sum_v1 <- timed("interview windows", "v1", {
    climatic4economist::extr_spell_by_interview(survey_v1, spells_ind_v1, by = ID,
                                                id = hhid, interview = interview,
                                                interval = config$interval,
                                                n_lags = config$n_lags)
})
sum_cols <- grep("_sum$", names(summary), value = TRUE)
spell_sum_cols <- grep("^spell_.*_(max|mean|sum|n)$", names(summary), value = TRUE)
compare("window sums", summary, days_sum_v1, c("hhid", "lag"),
        setdiff(sum_cols, spell_sum_cols),
        note = "c4e gives NA for a window with less than 80% of its days")
compare("window spells", summary, spells_sum_v1, c("hhid", "lag"), spell_sum_cols,
        note = "c4e gives NA for a window with less than 80% of its days")
compare("window sums, min_coverage = 0", summary_all, days_sum_v1, c("hhid", "lag"),
        setdiff(sum_cols, spell_sum_cols))
compare("window spells, min_coverage = 0", summary_all, spells_sum_v1, c("hhid", "lag"),
        spell_sum_cols)

# the one-call wrapper equals the step-by-step chain
wrapper <- timed("weather_extremes()", "c4e", {
    c4e::weather_extremes(survey, daily_c4e, lat = lat, lon = lon, id = hhid,
                          interview = interview, above = config$above,
                          below = config$below, min_spell = config$min_spell,
                          unit = config$daily_to_unit,
                          window = c4e::window_lag(config$interval, config$n_lags))
})
step_chain <- c4e::summarise_by_interview(coord, spells, interval = config$interval,
                                          n_lags = config$n_lags)
compare("weather_extremes() vs steps", wrapper, step_chain, c("hhid", "lag"),
        c(sum_cols, spell_sum_cols), note = "both c4e")

# ==== Standardised precipitation index ==================================== ----

if (!is.null(config$monthly)) {
    monthly_c4e <- timed("read monthly", "c4e", keep_dates(c4e::read_climate(config$monthly)))
    monthly_v1 <- timed("read monthly", "v1", keep_dates(v1_raster(config$monthly)))
    pre <- timed("extract monthly", "c4e", c4e::extract_by_coord(monthly_c4e, points))
    pre_v1 <- timed("extract monthly", "v1",
                    climatic4economist::extract_by_coord(monthly_v1, points_v1))
    for (s in config$scale) {
        spi <- timed(paste0("SPI-", s), "c4e", c4e::calc_std_index(pre, scale = s))
        spi_v1 <- timed(paste0("SPI-", s), "v1",
                        climatic4economist::compute_spi(tibble::as_tibble(pre_v1),
                                                        time_scale = s))
        compare(paste0("SPI-", s), spi, wide_to_long(to_c4e_id(spi_v1), paste0("spi_", s)),
                c("ID", "date"), paste0("spi_", s))
    }
}

# ==== Cells of the administrative divisions =============================== ----

if (!is.null(config$boundaries)) {
    adm <- terra::vect(config$boundaries)
    first_days <- seq_len(min(31, terra::nlyr(daily_c4e)))
    cells <- timed("cells by division", "c4e",
                   c4e::extract_cell_by_poly(daily_c4e[[first_days]], adm))
    cells_v1 <- timed("cells by division", "v1",
                      climatic4economist::extract_cell_by_poly(daily_v1[[first_days]], adm))
    long <- \(x) {
        tibble::as_tibble(x)[c("x_cell", "y_cell", date_columns(x))] |>
            tidyr::pivot_longer(-c(x_cell, y_cell), names_to = "date") |>
            dplyr::mutate(x_cell = round(x_cell, 6), y_cell = round(y_cell, 6),
                          date = label_to_date(date)) |>
            dplyr::distinct()
    }
    compare("cells by division (31 days)", long(cells), long(cells_v1),
            c("x_cell", "y_cell", "date"), "value", note = "raster values per cell")
}

# ==== Report ============================================================== ----

table <- do.call(rbind, results)
table$status <- ifelse(table$compared == 0, "nothing compared",
                ifelse(table$agree == table$compared &
                           table$na_c4e_only + table$na_v1_only == 0, "identical",
                ifelse(table$agree == table$compared, "same values, NA differ",
                       "DIFFERENT")))
times <- do.call(rbind, timings) |>
    dplyr::summarise(secs = sum(secs), .by = c(step, side)) |>
    tidyr::pivot_wider(names_from = side, values_from = secs)

dir.create(config$out_dir, showWarnings = FALSE, recursive = TRUE)
stem <- file.path(config$out_dir, paste0("compare-v1-", gsub("[^A-Za-z0-9]+", "-",
                                                              tolower(config$name))))
utils::write.csv(table, paste0(stem, ".csv"), row.names = FALSE)

fmt <- function(df) {
    df[] <- lapply(df, \(v) if (is.numeric(v)) format(v, big.mark = ",", digits = 3) else v)
    c(paste0("| ", paste(names(df), collapse = " | "), " |"),
      paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
      apply(df, 1, \(row) paste0("| ", paste(row, collapse = " | "), " |")))
}
lines <- c(
    paste0("# c4e against climatic4economist: ", config$name), "",
    paste0("Run on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
    paste0("- ", sources[["c4e"]]), paste0("- ", sources[["v1"]]),
    paste0("- Households: ", nrow(survey), "; locations: ", nrow(id_map)),
    paste0("- Daily raster: ", terra::nlyr(daily_c4e), " days, ",
           paste(range(as.Date(terra::time(daily_c4e))), collapse = " to "),
           ", compared in ", unit),
    paste0("- Thresholds: above ", toString(config$above %||% "none"), ", below ",
           toString(config$below %||% "none"), "; spells of ", config$min_spell,
           "+ days; percentiles ", toString(config$p %||% "none"),
           "; windows of ", config$interval, ", lags 0 to ", config$n_lags),
    "",
    paste0("**", sum(table$status == "identical"), " of ", nrow(table),
           " columns identical; ", sum(table$status == "DIFFERENT"), " different.**"), "",
    "## Comparison", "",
    paste0("A value agrees when it is within a relative tolerance of ", config$tolerance,
           "; `na_c4e_only` counts values c4e leaves missing where v1 has one."), "",
    fmt(table), "",
    "## Time (seconds)", "", fmt(as.data.frame(times)), "",
    "## Differences by design", "",
    "- Windows with less than `min_coverage` (80%) of their days are missing in c4e and 0 in v1.",
    "- Location identifiers: v1 numbers locations by sorted coordinates, c4e names them by the coordinates; the outputs are joined on the coordinates.",
    "- Interview windows containing 29 February can differ by a day (documented in the c4e NEWS).")
writeLines(lines, paste0(stem, ".md"))
cat(lines, sep = "\n")
