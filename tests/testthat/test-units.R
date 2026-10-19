# Units: aliases, conversions, convert_unit() on rasters and tables (plan §2, §11.7)

# ==== Names and conversion factors ===========================================

test_that("unit spellings map to one canonical name", {
    expect_equal(canonical_unit("degC"), "C")
    expect_equal(canonical_unit(paste0(intToUtf8(176), "C")), "C")
    expect_equal(canonical_unit("Celsius"), "C")
    expect_equal(canonical_unit(" K "), "K")
    expect_equal(canonical_unit("kg m-2 s-1"), "kg/m2/s")
    expect_equal(canonical_unit("mm d-1"), "mm/day")
    expect_equal(canonical_unit("furlongs"), "furlongs")
    expect_null(canonical_unit(NULL))
    expect_null(canonical_unit(""))
    expect_null(canonical_unit(NA_character_))
})

test_that("fixed conversions and their inverses", {
    expect_equal(unit_conversion("K", "C")[c("factor", "offset")],
                 list(factor = 1, offset = -273.15))
    expect_equal(unit_conversion("C", "K")[c("factor", "offset")],
                 list(factor = 1, offset = 273.15))
    expect_equal(unit_conversion("C", "F")$factor, 1.8)
    expect_equal(unit_conversion("m", "mm")$factor, 1000)
    expect_equal(unit_conversion("mm", "m")$factor, 0.001)
    expect_equal(unit_conversion("degC", "C")[c("factor", "offset")],
                 list(factor = 1, offset = 0))
})

test_that("rates convert numerator and time denominator", {
    expect_equal(unit_conversion("kg m-2 s-1", "mm/day")$factor, 1)
    expect_equal(unit_conversion("kg m-2 s-1", "mm/day")$per, c("s", "day"))
    # fixed-length denominators resolve to one factor
    expect_equal(rate_factor(unit_conversion("kg/m2/s", "mm/day")), 86400)
    expect_equal(rate_factor(unit_conversion("m/s", "km/h")), 3.6)
    expect_equal(rate_factor(unit_conversion("m/day", "mm/day")), 1000)
})

test_that("impossible conversions are refused", {
    expect_snapshot(error = TRUE, unit_conversion("C", "mm"))
    expect_snapshot(error = TRUE, unit_conversion("mm/day", "mm"))
    expect_error(unit_conversion("C/day", "K/day"), "offset")
})

test_that("time steps are inferred from regular dates", {
    expect_equal(infer_time_step(as.Date("2022-01-01") + 0:9), "day")
    expect_equal(infer_time_step(seq(as.Date("2020-01-01"), by = "month",
                                     length.out = 24)), "month")
    expect_equal(infer_time_step(seq(as.Date("2000-01-01"), by = "year",
                                     length.out = 5)), "year")
    expect_equal(infer_time_step(as.POSIXct("2022-01-01", tz = "UTC") +
                                     3600 * 0:23), "hour")
    expect_null(infer_time_step(as.Date("2022-01-01")))
    expect_null(infer_time_step(NULL))
})

# ==== Rasters ================================================================

test_that("a raster converts with its unit, names and dates kept", {
    tmax <- synthetic_daily("tmax")[[1:5]]
    out  <- convert_unit(tmax, "C")

    expect_equal(terra::values(out), terra::values(tmax) - 273.15)
    expect_equal(unique(terra::units(out)), "C")
    expect_equal(names(out), names(tmax))
    expect_equal(terra::time(out), terra::time(tmax))
})

test_that("a raster without a unit needs `from`", {
    r <- terra::rast(nrows = 2, ncols = 2, vals = 1)
    expect_error(convert_unit(r, "C"), "from")
    expect_equal(terra::values(convert_unit(r, "mm", from = "m"))[1], 1000)
})

test_that("monthly totals follow the number of days in each month", {
    pre_month <- synthetic_monthly()[[1:3]]       # Jan, Feb, Mar 1984
    rate <- convert_unit(pre_month, "mm/day")     # mm/month -> mm/day
    expect_equal(terra::values(rate)[, 2],
                 terra::values(pre_month)[, 2] / 29)     # 1984 is a leap year
    back <- convert_unit(rate, "mm/month")
    expect_equal(terra::values(back), terra::values(pre_month))
})

test_that("a per-month conversion on daily data is refused", {
    pre <- synthetic_daily("pre")[[1:5]]
    expect_snapshot(error = TRUE, convert_unit(pre, "mm/month"))
})

# ==== Tables =================================================================

extract_points <- function(raster) {
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    points <- georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
    extract_by_coord(raster, points)
}

test_that("converting the raster or the extracted table gives the same values", {
    tmax <- synthetic_daily("tmax")[[1:5]]
    from_raster <- extract_points(convert_unit(tmax, "C"))
    wide <- extract_points(tmax) |>
        update_meta(key = "ID", unit = "K", shape = "wide",
                    unit_cols = c("x_cell", "y_cell"))

    from_table <- suppressMessages(convert_unit(wide, "C"))
    expect_equal(tibble::as_tibble(from_table), tibble::as_tibble(from_raster))
    expect_equal(c4e_meta(from_table, "unit"), "C")
    # coordinates are not data and stay untouched
    expect_equal(from_table$x_cell, wide$x_cell)
})

test_that("the unit to convert from is read from upstream and announced", {
    wide <- update_meta(tibble::tibble(ID = "1", `2022-01-01` = 300),
                        key = "ID", unit = "K", shape = "wide")
    expect_snapshot(out <- convert_unit(wide, "C"))
    expect_equal(out[["2022-01-01"]], 300 - 273.15)
})

# a long table with a level series, an excess, a percentile and a flag
long_tbl <- function() {
    x <- tibble::tibble(
        ID          = "1",
        date        = as.Date("2022-01-01") + 0:2,
        value       = c(0.031, 0.029, 0.045),          # metres
        day_abv_0.03 = value > 0.03,
        m_abv_0.03  = pmax(value - 0.03, 0),
        day_90p     = 0.04
    )
    new_c4e_tbl(x, list(
        key = "ID", unit = "m", shape = "long", date_col = "date",
        indicators = list(
            day_abv_0.03 = new_indicator("flag", direction = "above",
                                         threshold = 0.03, unit = "m"),
            m_abv_0.03   = new_indicator("excess", direction = "above",
                                         threshold = 0.03, unit = "m"),
            day_90p      = new_indicator("pct", p = 0.9, unit = "m")
        )
    ))
}

test_that("long tables convert the series, the indicators and their thresholds", {
    x   <- long_tbl()
    out <- convert_unit(x, "mm")

    expect_equal(out$value, x$value * 1000)
    expect_equal(out$m_abv_0.03, x$m_abv_0.03 * 1000)
    expect_equal(out$day_90p, x$day_90p * 1000)
    # flags are counts and do not change, but their threshold does
    expect_equal(out$day_abv_0.03, x$day_abv_0.03)

    registry <- c4e_meta(out)$indicators
    expect_equal(registry$day_abv_0.03$threshold, 30)
    expect_equal(registry$m_abv_0.03$threshold, 30)
    expect_equal(registry$m_abv_0.03$unit, "mm")
    expect_equal(registry$day_90p$unit, "mm")
})

test_that("an offset applies to levels, never to differences", {
    x <- new_c4e_tbl(
        tibble::tibble(ID = "1", date = as.Date("2022-01-01"), value = 305,
                       K_abv_300 = 5),
        list(key = "ID", unit = "K", shape = "long", date_col = "date",
             indicators = list(K_abv_300 = new_indicator(
                 "excess", direction = "above", threshold = 300, unit = "K")))
    )
    out <- convert_unit(x, "C")
    expect_equal(out$value, 305 - 273.15)
    expect_equal(out$K_abv_300, 5)                 # 5 K above = 5 C above
    expect_equal(c4e_meta(out)$indicators$K_abv_300$threshold, 300 - 273.15)
})

test_that("a wide monthly table converts per month", {
    wide <- update_meta(
        tibble::tibble(ID = "1", `1984-01` = 31, `1984-02` = 29),
        key = "ID", unit = "mm/day", shape = "wide", time_step = "month"
    )
    out <- convert_unit(wide, "mm/month")
    expect_equal(c(out[["1984-01"]], out[["1984-02"]]), c(31 * 31, 29 * 29))
})

test_that("a plain data frame converts when `from` is given", {
    df <- data.frame(ID = "1", X2022.01.01 = 300, X2022.01.02 = 301)
    expect_error(convert_unit(df, "C"), "from")
    out <- convert_unit(df, "C", from = "K")
    expect_true(is_c4e_tbl(out))
    expect_equal(c4e_meta(out, "unit"), "C")
    expect_equal(out$X2022.01.02, 301 - 273.15)
})

test_that("chosen columns can be converted explicitly", {
    df <- tibble::tibble(ID = "1", tmax = 300, tmin = 280, elevation = 1200)
    out <- convert_unit(df, "C", from = "K", cols = c(tmax, tmin))
    expect_equal(out$tmin, 280 - 273.15)
    expect_equal(out$elevation, 1200)
})

test_that("converting records the step and returns the same table when units agree", {
    out <- convert_unit(long_tbl(), "mm")
    history <- c4e_history(out)
    expect_equal(history$call, "convert_unit(to = \"mm\", from = \"m\")")

    same <- convert_unit(long_tbl(), "m")
    expect_identical(same, long_tbl())
})

# ==== Thresholds in the data's unit ==========================================

test_that("thresholds in another unit than the data are refused", {
    meta <- modify_meta(empty_meta(), list(unit = "C"))
    expect_equal(resolve_unit("degC", meta), "degC")
    expect_snapshot(out <- resolve_unit(NULL, meta))
    expect_equal(out, "C")
    expect_snapshot(error = TRUE, resolve_unit("K", meta))
    expect_null(resolve_unit(NULL, empty_meta()))
})

# ==== register_unit() ========================================================

test_that("projects can register their own units and aliases", {
    withr::defer(reset_units())
    register_unit("in", "mm", factor = 25.4, aliases = c(inch = "in"))

    expect_equal(canonical_unit("inch"), "in")
    expect_equal(unit_conversion("mm", "in")$factor, 1 / 25.4)
    df <- tibble::tibble(ID = "1", value = 2)
    expect_equal(convert_unit(df, "mm", from = "inch")$value, 50.8)
    expect_true(any(list_units()$from == "in"))

    reset_units()
    expect_false(any(list_units()$from == "in"))
    expect_error(register_unit("in", "mm", factor = 0), "factor")
})
