# The four wrappers and the presets (plan §8 chunk 11, §12)

fixture_file <- function(name) system.file("extdata", name, package = "c4e")
quiet <- function(expr) suppressMessages(expr)

# progress steps print their duration, which changes from run to run
scrub_time <- function(lines) gsub("\\[[0-9.]+ ?m?s\\]", "[time]", lines)

survey_data <- function() synthetic_survey()

# ==== weather_extremes() =====================================================

test_that("weather_extremes() equals the step-by-step chain", {
    out <- quiet(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                  lat = lat, lon = lon, id = hhid,
                                  interview = interview, preset = "heat"))

    coord <- prepare_coord(survey_data(), lat, lon, id = hhid, interview = interview)
    manual <- quiet(
        extract_by_coord(read_climate(fixture_file("tmax_daily.tif")),
                         georef_coord(coord)) |>
            convert_unit("C") |>
            calc_threshold_day(above = c(30, 35)) |>
            calc_spell(min_spell = 2) |>
            summarise_by_interview(coord, x = _, window = window_lag("1 year"))
    )
    expect_equal(tibble::as_tibble(out), tibble::as_tibble(manual))
    expect_equal(c4e_meta(out, "preset"), "heat")
    expect_equal(nrow(out), 20L)
})

test_that("the history lists the steps to copy and edit", {
    out <- quiet(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                  id = hhid, interview = interview, preset = "heat"))
    calls <- c4e_history(out)$call
    expect_match(calls[1], "^prepare_coord")
    expect_true(any(grepl("^calc_threshold_day\\(above = c\\(30, 35\\)", calls)))
    expect_match(calls[length(calls)], "^summarise_by_interview")
})

test_that("a specification block and progress steps are printed", {
    expect_snapshot(
        invisible(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                   id = hhid, interview = interview, preset = "heat")),
        transform = scrub_time)
})

test_that("verbose = FALSE silences the wrapper", {
    expect_silent(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                   id = hhid, interview = interview, preset = "heat",
                                   control = extremes_control(verbose = FALSE)))
})

test_that("thresholds that look like Celsius convert Kelvin data, and say so", {
    expect_message(
        out <- weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                id = hhid, interview = interview, above = 30,
                                control = extremes_control()),
        "Converting")
    expect_true("C_abv_30_sum" %in% names(out))
})

test_that("percentiles of precipitation are computed on wet days", {
    out <- quiet(weather_extremes(survey_data(), fixture_file("pre_daily.tif"),
                                  id = hhid, interview = interview,
                                  preset = "wet_days_p95"))
    expect_true(all(c("day_abv_95p_sum", "day_abv_99p_sum", "spell_abv_95p_max")
                    %in% names(out)))
    expect_equal(c4e_meta(out)$indicators$day_abv_95p_sum$p, 0.95)
})

test_that("keep_steps returns every intermediate table", {
    steps <- quiet(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                    id = hhid, interview = interview, preset = "heat",
                                    control = extremes_control(keep_steps = TRUE)))
    expect_named(steps, c("locations", "extracted", "indicators", "summary"))
    expect_true(all(vapply(steps, is_c4e_tbl, logical(1))))
})

test_that("dry_run describes the plan without computing", {
    expect_snapshot(
        out <- weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                id = hhid, interview = interview, preset = "heat",
                                control = extremes_control(dry_run = TRUE)),
        transform = scrub_time)
    expect_null(out)
})

test_that("a list of surveys is processed survey by survey and stacked", {
    survey <- survey_data()
    waves <- list(wave1 = survey[1:10, ], wave2 = survey[11:20, ])
    out <- quiet(weather_extremes(waves, fixture_file("tmax_daily.tif"),
                                  id = hhid, interview = interview, preset = "heat"))
    expect_equal(sort(unique(out$survey)), c("wave1", "wave2"))
    expect_equal(nrow(out), 20L)
    expect_true("day_abv_30_sum" %in% names(c4e_meta(out)$indicators))
})

test_that("boundaries summarise area shares by division", {
    out <- quiet(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                  id = hhid, interview = interview, preset = "heat",
                                  boundaries = synthetic_adm_div()))
    expect_equal(nrow(out), 20L)
    expect_true(all(out$day_abv_30_sum >= 0 & out$day_abv_30_sum <= 366))
})

# ==== Presets ================================================================

test_that("every preset runs on a matching fixture", {
    tmin <- quiet(read_climate(fixture_file("tmax_daily.tif"), variable = "tmin"))
    fixtures <- list(
        heavy_rain = fixture_file("pre_daily.tif"), wet_days_p95 = fixture_file("pre_daily.tif"),
        dry_spell = fixture_file("pre_daily.tif"), dry_days_p10 = fixture_file("pre_daily.tif"),
        heat = fixture_file("tmax_daily.tif"), heatwave_wmo = fixture_file("tmax_daily.tif"),
        hot_days_p90 = fixture_file("tmax_daily.tif"), cold = tmin, cold_days_p10 = tmin,
        drought_spi3 = fixture_file("pre_monthly.tif"))
    presets <- list_presets()
    expect_setequal(presets$preset, names(fixtures))

    for (name in presets$preset) {
        wrapper <- if (presets$wrapper[presets$preset == name] == "climate_indices") {
            climate_indices
        } else {
            weather_extremes
        }
        out <- quiet(wrapper(survey_data(), fixtures[[name]], id = hhid,
                             interview = interview, preset = name))
        expect_true(is_c4e_tbl(out), label = name)
        expect_equal(nrow(out), 20L, label = name)
        expect_equal(c4e_meta(out, "preset"), name, label = name)
    }
})

test_that("a preset on the wrong variable fails with a fix", {
    expect_snapshot(error = TRUE,
                    weather_extremes(survey_data(), fixture_file("pre_daily.tif"),
                                     id = hhid, interview = interview, preset = "heat"))
    expect_error(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                  id = hhid, interview = interview, preset = "rain"),
                 "Unknown preset")
})

test_that("explicit arguments override the preset", {
    out <- quiet(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"),
                                  id = hhid, interview = interview, preset = "heat",
                                  above = 33, spells = FALSE))
    expect_true("day_abv_33_sum" %in% names(out))
    expect_false(any(grepl("^spell|day_abv_30", names(out))))
})

# ==== climate_indices() ======================================================

test_that("climate_indices() equals the step-by-step chain", {
    out <- quiet(climate_indices(survey_data(), fixture_file("pre_monthly.tif"),
                                 id = hhid, interview = interview, scale = 3,
                                 below = -1))
    coord <- prepare_coord(survey_data(), lat, lon, id = hhid, interview = interview)
    manual <- quiet(
        extract_by_coord(read_climate(fixture_file("pre_monthly.tif")),
                         georef_coord(coord)) |>
            calc_std_index(scale = 3) |>
            calc_std_threshold(below = -1) |>
            summarise_by_interview(coord, x = _, window = window_lag("1 month"))
    )
    expect_equal(tibble::as_tibble(out), tibble::as_tibble(manual))
    expect_true(all(c("spi_3_mean", "spi3_blw_-1_sum") %in% names(out)))
})

test_that("daily precipitation is summed to months first", {
    expect_message(
        out <- climate_indices(survey_data(), fixture_file("pre_daily.tif"),
                               id = hhid, interview = interview, scale = 1,
                               window = window_lag("6 months")),
        "Aggregating")
    expect_true("spi_1_mean" %in% names(out))
})

# ==== static_controls() ======================================================

static_layers <- function() {
    template <- terra::rast(fixture_file("tmax_daily.tif"))[[1]]
    elevation <- terra::rast(template, vals = seq(500, 1550, length.out = 36))
    zones <- terra::rast(template, vals = rep(c(1, 2, 3), 12))
    list(elevation = elevation, aez = zones)
}

test_that("static controls summarise terrain, zones and distances per household", {
    border <- terra::as.lines(synthetic_adm_div())
    out <- quiet(static_controls(survey_data(), static_layers(), id = hhid,
                                 buffer = c(0, 20000),
                                 distance_to = list(border = border)))

    expect_equal(nrow(out), 20L)
    expect_true(all(c("elevation", "slope", "TRI", "roughness", "aez",
                      "elevation_20km", "aez_20km", "dist_border_km") %in% names(out)))
    # a categorical layer is never averaged
    expect_true(all(out$aez %in% 1:3))
    expect_true(all(out$aez_20km %in% 1:3))
    expect_equal(c4e_meta(out)$indicators$aez_20km$stat, "mode")
    expect_equal(c4e_meta(out, "key"), "hhid")
})

# ==== time_varying_controls() ================================================

test_that("time-varying controls take the layer of the right year", {
    template <- terra::rast(fixture_file("tmax_daily.tif"))[[1]]
    pop <- terra::rast(template, nlyrs = 3, vals = rep(c(100, 200, 300), each = 36))
    terra::time(pop) <- as.Date(c("2021-01-01", "2022-01-01", "2023-01-01"))

    out <- quiet(time_varying_controls(survey_data(), list(pop = pop), id = hhid,
                                       interview = interview, match = "previous_year",
                                       climate = list(tmax = fixture_file("tmax_daily.tif"))))
    expect_equal(nrow(out), 20L)
    # all interviews are in 2023, so the previous year is 2022
    expect_true(all(out$pop == 200))
    expect_true(all(out$pop_year == 2022))
    expect_true(all(out$pop_density > 0))
    expect_true(all(c("tmax_mean", "tmax_sd") %in% names(out)))
    expect_equal(c4e_meta(out)$indicators$pop$period, "previous_year")

    same <- quiet(time_varying_controls(survey_data(), list(pop = pop), id = hhid,
                                        interview = interview, match = "same_year"))
    expect_true(all(same$pop == 300))
})

test_that("a survey year without its layer warns, and nearest takes the closest", {
    template <- terra::rast(fixture_file("tmax_daily.tif"))[[1]]
    pop <- terra::rast(template, nlyrs = 2, vals = rep(c(100, 200), each = 36))
    terra::time(pop) <- as.Date(c("2020-01-01", "2021-01-01"))

    expect_warning(
        out <- quiet(time_varying_controls(survey_data(), list(pop = pop), id = hhid,
                                           interview = interview, match = "same_year")),
        "no layer for survey year")
    expect_true(all(is.na(out$pop)))

    nearest <- quiet(time_varying_controls(survey_data(), list(pop = pop), id = hhid,
                                           interview = interview, match = "nearest"))
    expect_true(all(nearest$pop == 200 & nearest$pop_year == 2021))
})

test_that("control columns are labelled with their radius and year rule", {
    out <- quiet(static_controls(survey_data(), static_layers(), id = hhid,
                                 buffer = c(0, 20000), terrain = NULL))
    labels <- c4e_labels(out)
    expect_equal(labels[["aez_20km"]], "mode of aez within 20 km")
    expect_equal(labels[["elevation"]], "elevation")
    expect_false(any(c("slope", "TRI") %in% names(out)))
})

test_that("control wrappers stack a list of surveys and support dry runs", {
    survey <- survey_data()
    waves <- list(wave1 = survey[1:10, ], wave2 = survey[11:20, ])
    out <- quiet(static_controls(waves, static_layers(), id = hhid))
    expect_equal(nrow(out), 20L)
    expect_equal(sort(unique(out$survey)), c("wave1", "wave2"))

    expect_null(quiet(static_controls(survey, static_layers(), id = hhid,
                                      control = controls_control(dry_run = TRUE))))
})
