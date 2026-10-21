# Daily indicators (plan §8 chunk 7): v2 functions equal the v1 ones on the
# fixtures, register every column, and need no context argument after
# extraction.

extracted <- function(name = "tmax_daily.tif", layers = NULL) {
    raster <- suppressMessages(read_climate(
        system.file("extdata", name, package = "c4e")))
    if (!is.null(layers)) raster <- raster[[layers]]
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    points <- georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
    extract_by_coord(raster, points)
}

# compare chosen columns, ordered by unit and date (and month for lookups)
same_columns <- function(v2, v1, cols, order_by = c("ID", "date")) {
    a <- tibble::as_tibble(v2)[c(order_by, cols)] |>
        dplyr::arrange(dplyr::across(dplyr::all_of(order_by)))
    b <- tibble::as_tibble(v1)[c(order_by, cols)] |>
        dplyr::arrange(dplyr::across(dplyr::all_of(order_by)))
    expect_equal(a, b)
}

# ==== calc_threshold_day() ===================================================

test_that("absolute thresholds equal find_extr_abs_day()", {
    wide <- extracted()
    v2 <- calc_threshold_day(wide, above = c(300, 305), below = 290)
    cols <- c("value", "day_abv_300", "day_abv_305", "day_blw_290",
              "K_abv_300", "K_abv_305", "K_blw_290")
    v1 <- v1_ref("indicators_abs",
                 find_extr_abs_day(wide, u_thresh = c(300, 305), l_thresh = 290, unit = "K"),
                 keep = c("ID", "date", cols))

    same_columns(v2, v1, cols)
})

test_that("the thresholds are registered with their unit and direction", {
    out <- calc_threshold_day(extracted(layers = 1:30), above = 300, below = 290)
    meta <- c4e_meta(out)

    expect_equal(meta$shape, "long")
    expect_equal(meta$date_col, "date")
    expect_equal(meta$unit, "K")
    expect_equal(meta$indicators$day_abv_300[c("kind", "direction", "threshold", "unit")],
                 list(kind = "flag", direction = "above", threshold = 300, unit = "K"))
    expect_equal(meta$indicators$K_blw_290$kind, "excess")
    expect_equal(meta$indicators$K_blw_290$direction, "below")
    expect_equal(c4e_history(out)$call[2],
                 "calc_threshold_day(above = 300, below = 290, unit = \"K\")")
})

test_that("thresholds in another unit than the data are refused", {
    wide <- extracted(layers = 1:5)
    expect_error(calc_threshold_day(wide, above = 30, unit = "C"),
                 "convert_unit")
    out <- calc_threshold_day(convert_unit(wide, "C"), above = 30)
    expect_true("C_abv_30" %in% names(out))
})

test_that("per-unit thresholds come from a table", {
    wide <- extracted(layers = 1:31)
    limits <- tibble::tibble(ID = unique(wide$ID), local = seq(295, 306, length.out = 12))
    out <- calc_threshold_day(wide, above = limits)

    v1_like <- v1_ref("indicators_long_31", find_extr_abs_day(wide),
                      keep = c("ID", "date", "value")) |>
        dplyr::left_join(limits, by = "ID") |>
        dplyr::mutate(day_abv_local = value > local)
    same_columns(out, v1_like, "day_abv_local")
    expect_equal(c4e_meta(out)$indicators$day_abv_local$threshold, "local")
})

test_that("conditions written as expressions are registered as flags", {
    long <- calc_threshold_day(extracted(layers = 1:60), above = 300)
    out <- calc_condition(long, mild = value > 295 & value < 300)
    expect_true(is.logical(out$mild))
    expect_equal(out$mild, out$value > 295 & out$value < 300)
    expect_equal(c4e_meta(out)$indicators$mild$kind, "flag")
    expect_equal(c4e_meta(out)$indicators$mild$condition, "value > 295 & value < 300")
    expect_error(calc_condition(long, oops = value + 1), "TRUE or FALSE")
})

# ==== calc_spell() ===========================================================

test_that("spells equal find_spell() and follow every registered flag", {
    wide <- extracted()
    v1 <- v1_ref("indicators_spells",
                 find_extr_abs_day(wide, u_thresh = 303, l_thresh = 293) |>
                     find_spell(min_spell = 3),
                 keep = c("ID", "date", "spell_abv_303", "spell_blw_293"))
    v2 <- calc_threshold_day(wide, above = 303, below = 293) |>
        calc_spell(min_spell = 3)

    same_columns(v2, v1, c("spell_abv_303", "spell_blw_293"))
    entry <- c4e_meta(v2)$indicators$spell_abv_303
    expect_equal(entry[c("kind", "base", "min_spell")],
                 list(kind = "spell", base = "day_abv_303", min_spell = 3))
    # the flags are still there
    expect_true("day_abv_303" %in% names(v2))
})

test_that("spells work on a v1 table without a registry", {
    v1 <- v1_ref("indicators_v1_table",
                 tibble::as_tibble(find_extr_abs_day(extracted(layers = 1:90),
                                                     u_thresh = 303)))
    out <- calc_spell(v1, min_spell = 2)
    expect_equal(out$spell_abv_303,
                 v1_ref("indicators_v1_table_spells",
                        find_spell(v1, min_spell = 2)$spell_abv_303))
})

test_that("the minimum spell length is read from upstream spells", {
    long <- calc_threshold_day(extracted(layers = 1:60), above = c(300, 303)) |>
        calc_spell(min_spell = 4)
    long <- dplyr::select(long, -spell_abv_303)
    expect_snapshot(out <- calc_spell(long))
    expect_equal(c4e_meta(out)$indicators$spell_abv_303$min_spell, 4)
})

# ==== Percentiles ============================================================

test_that("monthly percentiles equal calc_pct_day()", {
    wide <- extracted("pre_daily.tif")
    v2 <- calc_percentile(wide, p = c(0.1, 0.9), exclude_below = 0.1, yearly = TRUE)
    cols <- c("day_10p", "day_90p", "yr_10p", "yr_90p")
    v1 <- v1_ref("indicators_pct",
                 calc_pct_day(wide, p = c(0.1, 0.9), l_thresh = 0.1, yearly = TRUE),
                 keep = c("ID", "month", cols))

    same_columns(v2, v1, cols, order_by = c("ID", "month"))
    meta <- c4e_meta(v2)
    expect_equal(meta$shape, "lookup")
    expect_equal(meta$indicators$day_90p[c("kind", "p", "period", "exclude_below")],
                 list(kind = "pct", p = 0.9, period = "month", exclude_below = 0.1))
    expect_equal(meta$indicators$yr_90p$period, "year")
})

test_that("a baseline restricts the dates the percentiles use", {
    wide <- extracted()
    v2 <- calc_percentile(wide, p = 0.9, baseline = c("2021-01-01", "2021-12-31"))
    v1 <- v1_ref("indicators_pct_baseline",
                 calc_pct_day(select_by_dates(tibble::as_tibble(wide), to = "2021-12-31"),
                              p = 0.9),
                 keep = c("ID", "month", "day_90p"))
    same_columns(v2, v1, "day_90p", order_by = c("ID", "month"))
    expect_equal(c4e_meta(v2, "date_range"), as.Date(c("2021-01-01", "2021-12-31")))
})

test_that("relative flags equal find_extr_rel_day(), upper and lower tails", {
    wide <- extracted()
    pct <- calc_percentile(wide, p = c(0.1, 0.9))
    expect_snapshot(v2 <- calc_percentile_day(wide, pct))

    v1_upper <- v1_ref("indicators_rel_upper",
                       find_extr_rel_day(wide, u_thresh = calc_pct_day(wide, p = 0.9),
                                         unit = "K"),
                       keep = c("ID", "date", "day_abv_90p", "K_abv_90p"))
    v1_lower <- v1_ref("indicators_rel_lower",
                       find_extr_rel_day(wide, l_thresh = calc_pct_day(wide, p = 0.1),
                                         unit = "K"),
                       keep = c("ID", "date", "day_blw_10p", "K_blw_10p"))
    same_columns(v2, v1_upper, c("day_abv_90p", "K_abv_90p"))
    same_columns(v2, v1_lower, c("day_blw_10p", "K_blw_10p"))

    entry <- c4e_meta(v2)$indicators$day_abv_90p
    expect_equal(entry[c("kind", "direction", "threshold", "p")],
                 list(kind = "flag", direction = "above", threshold = "day_90p", p = 0.9))
})

test_that("percentile tables must describe the same variable", {
    tmax <- extracted(layers = 1:60)
    pre_pct <- calc_percentile(extracted("pre_daily.tif", layers = 1:60), p = 0.9)
    expect_error(calc_percentile_day(tmax, pre_pct), "variable")
})

# ==== Spell percentiles and excess ===========================================

test_that("spell percentiles and spell excess equal the v1 functions", {
    wide <- extracted("pre_daily.tif")
    cols <- c("spell_blw_1_50p", "spell_blw_1_90p")
    v1_pct <- v1_ref("indicators_spell_pct",
                     calc_pct_spell(find_extr_abs_day(wide, l_thresh = 1),
                                    p = c(0.5, 0.9), min_spell = 2),
                     keep = c("ID", "month", cols))
    v1_rel <- v1_ref("indicators_spell_rel", {
        v1_days <- find_extr_abs_day(wide, l_thresh = 1)
        suppressMessages(find_extr_spell_rel(
            find_spell(v1_days, min_spell = 2),
            calc_pct_spell(v1_days, p = c(0.5, 0.9), min_spell = 2)))
    }, keep = c("ID", "date", cols))

    spells <- calc_threshold_day(wide, below = 1) |> calc_spell(min_spell = 2)
    pct <- calc_spell_percentile(spells, p = c(0.5, 0.9))
    same_columns(pct, v1_pct, c("spell_blw_1_50p", "spell_blw_1_90p"),
                 order_by = c("ID", "month"))
    expect_equal(c4e_meta(pct)$indicators$spell_blw_1_90p$base, "spell_blw_1")

    out <- calc_spell_excess(spells, pct)
    same_columns(out, v1_rel, c("spell_blw_1_50p", "spell_blw_1_90p"))
    expect_equal(c4e_meta(out)$indicators$spell_blw_1_90p$kind, "excess")
})

# ==== calc_heatwave() ========================================================

test_that("WMO heatwaves equal find_wmo_heatwave()", {
    wide <- extracted()
    v2 <- calc_heatwave(wide, excess = 5, min_spell = 2)
    v1 <- v1_ref("indicators_heatwave",
                 find_wmo_heatwave(wide, excess = 5, min_spell = 2),
                 keep = c("ID", "date", "spell_wmo"))
    same_columns(v2, v1, "spell_wmo")
    expect_equal(c4e_meta(v2)$indicators$spell_wmo$definition, "wmo")

    pre <- extracted("pre_daily.tif", layers = 1:31)
    expect_error(calc_heatwave(pre), "temperature")
})

# ==== Splitting and flow =====================================================

test_that("indicators split by unit give the same result", {
    wide <- extracted(layers = 1:120)
    whole <- calc_threshold_day(wide, above = 300) |> calc_spell(min_spell = 2)

    withr::local_options(c4e.mem_limit = "4KB")
    split <- suppressMessages(
        calc_threshold_day(wide, above = 300) |> calc_spell(min_spell = 2))
    expect_equal(tibble::as_tibble(split), tibble::as_tibble(whole))
    expect_equal(c4e_meta(split)$indicators, c4e_meta(whole)$indicators)
})

test_that("no context argument is typed after extraction", {
    out <- extracted(layers = 1:120) |>
        convert_unit("C") |>
        calc_threshold_day(above = 30) |>
        calc_spell() |>
        calc_spell_percentile(p = 0.9)

    expect_equal(c4e_meta(out, "unit"), "C")
    expect_equal(c4e_meta(out)$indicators$spell_abv_30_90p$min_spell, 2)
    expect_equal(c4e_history(out)$call[1:3],
                 c("extract_by_coord()", "convert_unit(to = \"C\", from = \"K\")",
                   "calc_threshold_day(above = 30, unit = \"C\")"))
})
