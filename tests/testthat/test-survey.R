# Survey side (plan §8 chunk 9, §9.1, §9.3, §11.3)

survey_coord <- function() {
    prepare_coord(synthetic_survey(), lat, lon, id = hhid, interview = interview)
}

# hot days and their spells at the survey locations, in C
hot_days <- function() {
    tmax <- suppressMessages(read_climate(
        system.file("extdata", "tmax_daily.tif", package = "c4e")))
    points <- suppressMessages(georef_coord(survey_coord()))
    suppressMessages(
        extract_by_coord(tmax, points) |>
            convert_unit("C") |>
            calc_threshold_day(above = c(25, 30)) |>
            calc_spell(min_spell = 2)
    )
}

same_rows <- function(v2, v1, cols, order_by = c("hhid", "lag")) {
    a <- tibble::as_tibble(v2)[c(order_by, cols)] |>
        dplyr::arrange(dplyr::across(dplyr::all_of(order_by)))
    b <- tibble::as_tibble(v1)[c(order_by, cols)] |>
        dplyr::arrange(dplyr::across(dplyr::all_of(order_by)))
    expect_equal(a, b)
}

# ==== prepare_coord() and georef_coord() =====================================

test_that("location IDs are stable across subsets and orderings", {
    survey <- synthetic_survey()
    whole <- prepare_coord(survey, lat, lon)
    part <- prepare_coord(survey[c(20, 3, 7), ], lat, lon)

    matched <- dplyr::inner_join(tibble::as_tibble(whole), tibble::as_tibble(part),
                                 by = "hhid")
    expect_equal(matched$ID.x, matched$ID.y)
    expect_type(whole$ID, "character")
    expect_equal(dplyr::n_distinct(whole$ID), 12L)
    expect_match(whole$ID[1], "^-?[0-9.]+_-?[0-9.]+$")
})

test_that("sequential IDs are still available", {
    out <- prepare_coord(data.frame(lat = c(1, 2, 1), lon = c(10, 20, 10)), lat, lon,
                         id_rule = "sequence")
    expect_equal(sort(unique(out$ID)), c("1", "2"))
})

test_that("prepare_coord records the survey's columns", {
    meta <- c4e_meta(survey_coord())
    expect_equal(meta$key, "ID")
    expect_equal(meta$survey, list(lon = "lon", lat = "lat", id = "hhid",
                                   interview = "interview"))
    expect_equal(meta$id_rule, "coordinates")
})

test_that("georef_coord reads the coordinate columns and announces the CRS", {
    expect_snapshot(points <- georef_coord(survey_coord()))
    expect_s4_class(points, "SpatVector")
    expect_equal(nrow(points), 12L)
    expect_true(terra::same.crs(points, "EPSG:4326"))
    expect_error(georef_coord(synthetic_survey() |> dplyr::mutate(ID = hhid)), "geom")
})

# ==== summarise_by_interview() ===============================================

test_that("window summaries equal extr_day_by_interview() and extr_spell_by_interview()", {
    coord <- survey_coord()
    indicators <- hot_days()
    out <- summarise_by_interview(coord, indicators, interval = "1 year", n_lags = 1)

    v1_days <- v1_ref("survey_days",
                      extr_day_by_interview(tibble::as_tibble(coord),
                                            tibble::as_tibble(indicators),
                                            by = ID, id = hhid, interview = interview,
                                            interval = "1 year", n_lags = 1))
    v1_spells <- v1_ref("survey_spells",
                        extr_spell_by_interview(tibble::as_tibble(coord),
                                                tibble::as_tibble(indicators),
                                                by = ID, id = hhid, interview = interview,
                                                interval = "1 year", n_lags = 1))
    same_rows(out, v1_days, c("day_abv_25_sum", "day_abv_30_sum", "C_abv_30_sum"))
    same_rows(out, v1_spells, c("spell_abv_30_max", "spell_abv_30_mean",
                                "spell_abv_30_sum", "spell_abv_30_n"))
})

test_that("window summaries record what they summarised", {
    out <- summarise_by_interview(survey_coord(), hot_days(), interval = "1 year")
    meta <- c4e_meta(out)

    expect_equal(meta$key, "hhid")
    expect_equal(meta$shape, "summary")
    expect_equal(meta$window[c("type", "interval", "n_lags")],
                 list(type = "lag", interval = "1 year", n_lags = 0))
    entry <- meta$indicators$day_abv_30_sum
    expect_equal(entry[c("kind", "base", "stat", "direction", "threshold", "unit")],
                 list(kind = "agg", base = "day_abv_30", stat = "sum",
                      direction = "above", threshold = 30, unit = "C"))
    expect_equal(c4e_history(out)$call[6],
                 "summarise_by_interview(interval = \"1 year\", n_lags = 0, min_coverage = 0.8)")
})

test_that("windows reaching beyond the data are missing, not zero", {
    coord <- survey_coord()
    indicators <- hot_days()
    # the data start in 2021, so two years before a 2023 interview is
    # incomplete, and a warning says how many windows that leaves missing
    expect_warning(
        out <- summarise_by_interview(coord, indicators, interval = "1 year", n_lags = 2),
        "20 of 60 household windows are `NA`")
    lag_2 <- dplyr::filter(tibble::as_tibble(out), lag == 2)
    expect_true(all(is.na(lag_2$day_abv_30_sum)))
    expect_false(any(c(".short", ".no_data") %in% names(out)))

    expect_no_warning(all_windows <- summarise_by_interview(
        coord, indicators, interval = "1 year", n_lags = 2, min_coverage = 0))
    expect_false(anyNA(all_windows$day_abv_30_sum))
})

test_that("the warning counts windows with no data at all", {
    coord <- survey_coord()
    coord$interview <- as.Date("2030-01-01")
    expect_snapshot(out <- summarise_by_interview(coord, hot_days(), interval = "1 year"))
    expect_true(all(is.na(out$day_abv_30_sum)))
})

test_that("households without an interview date are reported and dropped", {
    coord <- survey_coord()
    coord$interview[c(1, 5)] <- NA
    expect_snapshot(out <- summarise_by_interview(coord, hot_days(), interval = "1 year"))
    expect_equal(nrow(out), 18L)
})

test_that("summaries split by location give the same result", {
    coord <- survey_coord()
    indicators <- hot_days()
    whole <- summarise_by_interview(coord, indicators, interval = "6 months", n_lags = 1)
    withr::local_options(c4e.mem_limit = "20KB")
    split <- suppressMessages(
        summarise_by_interview(coord, indicators, interval = "6 months", n_lags = 1))
    expect_equal(dplyr::arrange(tibble::as_tibble(split), hhid, lag),
                 dplyr::arrange(tibble::as_tibble(whole), hhid, lag))
})

# ==== Window objects =========================================================

test_that("lag windows follow the v1 rule", {
    keys <- tibble::tibble(.by_key = "a", .interview = as.Date("2023-03-15"))
    w <- window_frame(window_lag("1 year", n_lags = 1), keys)
    expect_equal(w$w_start, as.Date(c("2022-03-15", "2021-03-15")))
    expect_equal(w$w_end, as.Date(c("2023-03-14", "2022-03-15")))
})

test_that("season windows take the last complete season before the interview", {
    keys <- tibble::tibble(.by_key = c("a", "b"),
                           .interview = as.Date(c("2023-03-15", "2023-10-15")))
    rainy <- window_season(start_month = 6, end_month = 9, years_back = 0:1)
    w <- window_frame(rainy, keys) |> dplyr::arrange(.by_key, lag)

    # interviewed in March 2023: the last finished rainy season is June-Sept 2022
    expect_equal(w$w_start[1:2], as.Date(c("2022-05-31", "2021-05-31")))
    expect_equal(w$w_end[1:2], as.Date(c("2022-09-30", "2021-09-30")))
    # interviewed in October 2023: the 2023 season is over
    expect_equal(w$w_end[3], as.Date("2023-09-30"))

    winter <- window_frame(window_season("Nov", "Feb"), keys[1, ])
    expect_equal(c(winter$w_start, winter$w_end), as.Date(c("2022-10-31", "2023-02-28")))
})

test_that("season, fixed and since windows summarise the right days", {
    coord <- survey_coord()
    indicators <- hot_days()
    long <- tibble::as_tibble(indicators)

    fixed <- summarise_by_interview(coord, indicators,
                                    window = window_fixed("2022-01-01", "2022-12-31"))
    expected <- long |>
        dplyr::filter(date >= as.Date("2022-01-01"), date <= as.Date("2022-12-31")) |>
        dplyr::summarise(n = sum(day_abv_30), .by = ID)
    check <- dplyr::left_join(tibble::as_tibble(coord), expected, by = "ID") |>
        dplyr::left_join(tibble::as_tibble(fixed), by = "hhid")
    expect_equal(check$day_abv_30_sum, check$n)
    expect_equal(c4e_meta(fixed)$window$type, "fixed")

    season <- summarise_by_interview(coord, indicators,
                                     window = window_season(6, 9, years_back = 0))
    expect_equal(nrow(season), 20L)
    expect_equal(c4e_meta(season)$window$type, "season")

    coord$planting <- coord$interview - 100
    since <- summarise_by_interview(coord, indicators, window = window_since(planting))
    first <- dplyr::filter(tibble::as_tibble(coord), hhid == hhid[1])
    days <- dplyr::filter(long, ID == first$ID, date > first$planting,
                          date < first$interview)
    expect_equal(dplyr::filter(tibble::as_tibble(since), hhid == first$hhid)$day_abv_30_sum,
                 sum(days$day_abv_30))
})


test_that("calendar windows take their bounds from the survey, row by row", {
    keys <- tibble::tibble(
        .by_key    = c("a", "b", "c"),
        .interview = as.Date(c("2023-11-20", "2023-06-15", "2023-08-01")),
        .sos       = c(92, 92, 260),
        .eos       = c(297, 297, 159))
    w <- window_frame(window_calendar(sos, eos), keys) |> dplyr::arrange(.by_key)

    # a: interviewed once the 2023 season had closed, so that is the window
    expect_equal(c(w$w_start[1], w$w_end[1]), as.Date(c("2023-04-01", "2023-10-24")))
    # b: same season, interviewed inside it, so the last CLOSED one is 2022's
    expect_equal(c(w$w_start[2], w$w_end[2]), as.Date(c("2022-04-01", "2022-10-24")))
    # c: an end before its start closes in the following year
    expect_equal(c(w$w_start[3], w$w_end[3]), as.Date(c("2022-09-16", "2023-06-08")))

    # the three rows share nothing but the shape: one window each
    expect_equal(nrow(w), 3L)

    # dekads are ten-day steps from 1 January and may run negative, which is
    # how FAO ASIS encodes a season reaching back into the previous year
    dek <- window_frame(window_calendar(sos, eos, unit = "dekad"),
                        dplyr::mutate(keys[1, ], .sos = -2, .eos = 14))
    expect_equal(c(dek$w_start, dek$w_end), as.Date(c("2022-12-10", "2023-05-20")))

    # years_back steps whole seasons, as window_season() does
    back <- window_frame(window_calendar(sos, eos, years_back = 0:2), keys[1, ])
    expect_equal(back$lag, 0:2)
    expect_equal(lubridate::year(back$w_end), c(2023, 2022, 2021))

    # a row with no season is dropped, not an error
    expect_equal(nrow(window_frame(window_calendar(sos, eos),
                                   dplyr::mutate(keys[1, ], .sos = NA))), 0L)

    expect_equal(describe_window(window_calendar(sos, eos)),
                 "season sos to eos (doy), 0 season(s) back")
})

test_that("a calendar window summarises the days inside each row's own season", {
    coord <- survey_coord()
    indicators <- hot_days()
    long <- tibble::as_tibble(indicators)
    coord$sos <- 60L
    coord$eos <- 200L

    cal <- summarise_by_interview(coord, indicators,
                                  window = window_calendar(sos, eos),
                                  min_coverage = 0)
    expect_equal(c4e_meta(cal)$window$type, "calendar")

    first <- dplyr::filter(tibble::as_tibble(coord), hhid == hhid[1])
    w <- window_frame(window_calendar(sos, eos),
                      tibble::tibble(.by_key = first$ID,
                                     .interview = first$interview,
                                     .sos = first$sos, .eos = first$eos))
    days <- dplyr::filter(long, ID == first$ID, date > w$w_start, date <= w$w_end)
    expect_equal(dplyr::filter(tibble::as_tibble(cal), hhid == first$hhid)$day_abv_30_sum,
                 sum(days$day_abv_30))

    # a missing bound column is caught by name
    coord$eos <- NULL
    expect_error(summarise_by_interview(coord, indicators,
                                        window = window_calendar(sos, eos)),
                 "eos")
})

# ==== summarise_by_period() ==================================================

test_that("period summaries count days per unit and month", {
    indicators <- hot_days()
    out <- summarise_by_period(indicators, period = "month")
    expected <- tibble::as_tibble(indicators) |>
        dplyr::mutate(period = lubridate::floor_date(date, "month")) |>
        dplyr::summarise(day_abv_30_sum = sum(day_abv_30), .by = c(ID, period))
    check <- dplyr::inner_join(tibble::as_tibble(out), expected, by = c("ID", "period"))
    expect_equal(nrow(check), 12L * 36L)
    expect_equal(check$day_abv_30_sum.x, check$day_abv_30_sum.y)
    expect_equal(c4e_meta(out)$indicators$day_abv_30_sum$period, "month")
})

# ==== merge_with_survey() ====================================================

test_that("merging a long daily table with the survey warns about its size", {
    coord <- survey_coord()
    indicators <- hot_days()
    withr::local_options(c4e.mem_limit = "100KB")
    expect_warning(merged <- merge_with_survey(coord, indicators),
                   "summarise_by_interview")
    expect_true(is_c4e_tbl(merged))
    expect_true("hhid" %in% c4e_meta(merged, "survey_cols"))
})

# ==== aggregate_to_adm() =====================================================

test_that("division averages equal agg_to_adm_div()", {
    cells <- tibble::tibble(
        ID_adm_div = c("1", "1", "2", "2"), x_cell = c(1, 2, 3, 4),
        y_cell = 0, coverage_fraction = c(1, 0.5, 0.2, 0.8), lag = 0,
        day_abv_30_sum = c(5, 10, 2, 8), spell_abv_30_max = c(2, 3, 1, 2))
    cells <- new_c4e_tbl(cells, list(
        key = "ID_adm_div", unit_cols = c("x_cell", "y_cell", "coverage_fraction", "lag"),
        indicators = list(day_abv_30_sum = new_indicator("agg", stat = "sum"),
                          spell_abv_30_max = new_indicator("agg", stat = "max"))))
    out <- aggregate_to_adm(cells)
    v1 <- v1_ref("survey_adm_div",
                 tibble::as_tibble(agg_to_adm_div(tibble::as_tibble(cells),
                                                  match_col = "^day|^spell")))

    expect_equal(tibble::as_tibble(out)[names(v1)], tibble::as_tibble(v1))
    expect_equal(c4e_meta(out)$spatial_agg$level, "adm_div")
    expect_false("x_cell" %in% c4e_meta(out, "unit_cols"))
})

test_that("daily cell flags become area shares per division and day", {
    tmax <- suppressMessages(read_climate(
        system.file("extdata", "tmax_daily.tif", package = "c4e")))[[1:31]]
    cells <- extract_cell_by_poly(tmax, synthetic_adm_div()) |>
        calc_threshold_day(above = 300)
    shares <- aggregate_to_adm(cells)

    expect_equal(nrow(shares), 3L * 31L)
    day_one <- dplyr::filter(tibble::as_tibble(cells), ID_adm_div == "1",
                             date == as.Date("2021-01-01"))
    expected <- stats::weighted.mean(day_one$day_abv_300, day_one$coverage_fraction)
    expect_equal(dplyr::filter(tibble::as_tibble(shares), ID_adm_div == "1",
                               date == as.Date("2021-01-01"))$day_abv_300,
                 expected)
})


test_that("labels say area share after aggregating to divisions", {
    tmax <- suppressMessages(read_climate(
        system.file("extdata", "tmax_daily.tif", package = "c4e")))[[1:31]]
    cells <- extract_cell_by_poly(tmax, synthetic_adm_div()) |>
        calc_threshold_day(above = 300)

    ## Before aggregating, the column really does count days.
    expect_match(c4e_labels(cells)[["day_abv_300"]], "^days above")
    expect_match(c4e_labels(cells)[["K_abv_300"]], "^excess above")

    ## After it, the same column is a share of the division's area, and the
    ## excess is an area-weighted mean. The names cannot say so.
    shares <- aggregate_to_adm(cells)
    expect_match(c4e_labels(shares)[["day_abv_300"]],
                 "^share of division area above")
    expect_match(c4e_labels(shares)[["K_abv_300"]], "^area-weighted excess")

    ## The kind is left alone, because summarise_*() picks its statistics by
    ## kind and does not know "agg": relabelling must not change behaviour.
    expect_equal(c4e_meta(shares)$indicators$day_abv_300$kind, "flag")
    expect_no_error(summarise_by_period(shares, "month"))

    ## A condition keeps its own wording.
    cond <- calc_condition(cells, hot = value > 300)
    expect_match(c4e_labels(aggregate_to_adm(cond))[["hot"]],
                 "^share of division area with ")
})

test_that("a different spatial aggregation leaves labels alone", {
    ## Only the coverage-weighted mean over a division turns a count into a
    ## share; point and polygon extraction must read as before.
    out <- hot_days()
    expect_match(c4e_labels(out)[["day_abv_30"]], "^days above")
})

test_that("sd and cv are available as summary statistics", {
    out <- summarise_by_interview(survey_coord(), hot_days(), interval = "1 year",
                                  stats = list(flag = c("mean", "sd", "cv")))
    tb <- tibble::as_tibble(out)

    expect_true(all(c("day_abv_30_mean", "day_abv_30_sd", "day_abv_30_cv") %in%
                        names(tb)))
    ok <- is.finite(tb$day_abv_30_sd) & tb$day_abv_30_mean != 0
    expect_equal(tb$day_abv_30_cv[ok],
                 (tb$day_abv_30_sd / tb$day_abv_30_mean)[ok])
    expect_equal(c4e_meta(out)$indicators$day_abv_30_sd$stat, "sd")
})

test_that("cv is NA where the mean is zero, rather than zero", {
    flat <- summarise_by_interview(survey_coord(), hot_days(), interval = "1 year",
                                   stats = list(flag = c("mean", "cv")))
    tb <- tibble::as_tibble(flat)
    zero <- tb$day_abv_30_mean == 0
    if (any(zero)) expect_true(all(is.na(tb$day_abv_30_cv[zero])))
    expect_false(any(is.na(tb$day_abv_30_mean)))
})

test_that("an unknown statistic is still rejected", {
    expect_error(
        summarise_by_interview(survey_coord(), hot_days(), interval = "1 year",
                               stats = list(flag = "median")),
        "median"
    )
})

# ==== Window bounds, the value kind, lags and anomalies ===================

test_that("a window summary carries its own bounds", {
    out <- summarise_by_interview(survey_coord(), hot_days(),
                                  interval = "1 year", n_lags = 1)
    tb <- tibble::as_tibble(out)
    expect_true(all(c("w_start", "w_end") %in% names(tb)))
    expect_s3_class(tb$w_start, "Date")
    expect_s3_class(tb$w_end, "Date")

    ## the window is half-open and closes before the interview, so w_end is
    ## the day before it at lag 0
    interview <- synthetic_survey()
    first <- tb[tb$hhid == interview$hhid[1], ]
    own <- interview$interview[1]
    expect_equal(first$w_end[first$lag == 0], own - 1)
    expect_true(all(first$w_start < first$w_end))
    ## consecutive periods tile, so one lag closes where the next opens
    expect_equal(first$w_end[first$lag == 1], first$w_start[first$lag == 0])

    ## and the bounds say which window a row is, not which unit
    expect_equal(summary(out)$n_units, 20L)
})

test_that("the series itself is summarised when stats ask for it", {
    plain <- summarise_by_interview(survey_coord(), hot_days(),
                                    interval = "1 year")
    expect_false(any(grepl("^value_", names(tibble::as_tibble(plain)))))

    out <- summarise_by_interview(survey_coord(), hot_days(),
                                  interval = "1 year",
                                  stats = list(value = c("sum", "mean", "sd", "cv")))
    tb <- tibble::as_tibble(out)
    expect_true(all(c("value_sum", "value_mean", "value_sd", "value_cv") %in%
                    names(tb)))
    ## the indicators are still there, and the registry knows what the
    ## series columns are
    expect_true("day_abv_30_sum" %in% names(tb))
    expect_equal(c4e_meta(out)$indicators$value_mean$of, "value")
    expect_equal(c4e_meta(out)$indicators$value_mean$unit, "C")
    ok <- is.finite(tb$value_sd) & tb$value_mean != 0
    expect_equal(tb$value_cv[ok], (tb$value_sd / tb$value_mean)[ok])
})

test_that("window_lags() sets whichever field the window keeps", {
    expect_equal(window_lags(window_lag("1 year"), 0:9)$n_lags, 9L)
    expect_equal(window_lags(window_season("Jun", "Sep"), 0:2)$years_back, 0:2)
    expect_equal(window_lags(window_calendar(sos, eos), 0:2)$years_back, 0:2)
    expect_error(window_lags(window_fixed("2020-01-01", "2020-12-31"), 0:2),
                 "no earlier periods")
    expect_error(window_lags(window_lag("1 year"), -1), "0 or more")
    expect_error(window_lags("1 year", 0:2), "must be a window")
})

test_that("calc_anomaly() ranks a window against its own baseline", {
    ## min_coverage 0 because the fixture holds about a year of data, so
    ## the earlier lags are partial and would otherwise all be NA
    out <- summarise_by_interview(
        survey_coord(), hot_days(), min_coverage = 0,
        window = window_lags(window_lag("1 year"), 0:2))
    anom <- calc_anomaly(out, cols = "day_abv_30_sum", min_years = 2)
    tb <- tibble::as_tibble(anom)

    expect_equal(nrow(tb), 20)
    expect_true(all(c("day_abv_30_sum_pctl", "day_abv_30_sum_z") %in% names(tb)))
    expect_true(all(tb$baseline_n == 2))
    expect_true(all(tb$day_abv_30_sum_pctl >= 0 & tb$day_abv_30_sum_pctl <= 100,
                    na.rm = TRUE))

    ## the two forms agree on which way round a window sits, the percentile
    ## being a monotone transform of the z-score within a unit
    both <- stats::na.omit(tb[c("day_abv_30_sum_pctl", "day_abv_30_sum_z")])
    expect_true(all((both[[1]] > 50) == (both[[2]] > 0) |
                    both[[1]] == 50 | both[[2]] == 0))

    ## a baseline too short for min_years gives NA, not a number
    thin <- calc_anomaly(out, cols = "day_abv_30_sum", min_years = 30)
    expect_true(all(is.na(tibble::as_tibble(thin)$day_abv_30_sum_pctl)))
})

test_that("calc_anomaly() needs lags and the bounds", {
    one <- summarise_by_interview(survey_coord(), hot_days(),
                                  interval = "1 year")
    expect_error(calc_anomaly(one), "only lag 0")

    out <- summarise_by_interview(
        survey_coord(), hot_days(), min_coverage = 0,
        window = window_lags(window_lag("1 year"), 0:2))
    stripped <- tibble::as_tibble(out)[c("hhid", "lag", "day_abv_30_sum")]
    expect_error(calc_anomaly(stripped, id = "hhid"), "window bounds")

    expect_error(
        calc_anomaly(out, cols = "day_abv_30_sum", baseline = c(1800, 1810)),
        "No window falls in the baseline")
})

test_that("snap_to_valid_cell() moves only the points with no cell", {
    r <- suppressMessages(read_climate(
        system.file("extdata", "tmax_daily.tif", package = "c4e")))[[1]]
    mid <- terra::xyFromCell(r, terra::cellFromRowCol(r, 1, 1))
    r[terra::cellFromRowCol(r, 1, 1)] <- NA

    places <- tibble::tibble(
        place = 1:2,
        lon = c(mid[1, "x"], terra::xmin(r) - 50),   # in the hole, far away
        lat = c(mid[1, "y"], terra::ymin(r) - 50)
    )
    out <- suppressMessages(snap_to_valid_cell(places, r, radius_deg = 0.5))

    expect_equal(out$snapped, c(TRUE, FALSE))
    expect_equal(out$lon_given, places$lon)
    expect_false(out$lon[1] == places$lon[1] && out$lat[1] == places$lat[1])
    expect_equal(out$lon[2], places$lon[2])
    expect_false(is.na(terra::extract(
        r, terra::vect(as.data.frame(out[1, c("lon", "lat")]),
                       geom = c("lon", "lat"), crs = "EPSG:4326"),
        ID = FALSE)[[1]]))
})
