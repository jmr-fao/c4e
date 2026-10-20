# Export and inspection (plan §6, §8 chunk 10, §9.6, §9.7)

survey_coord <- function() {
    prepare_coord(synthetic_survey(), lat, lon, id = hhid, interview = interview)
}
hot_days <- function(layers = NULL) {
    tmax <- suppressMessages(read_climate(
        system.file("extdata", "tmax_daily.tif", package = "c4e")))
    if (!is.null(layers)) tmax <- tmax[[layers]]
    points <- suppressMessages(georef_coord(survey_coord()))
    suppressMessages(
        extract_by_coord(tmax, points) |>
            convert_unit("C") |>
            calc_threshold_day(above = 30) |>
            calc_spell(min_spell = 2)
    )
}
window_summary <- function() {
    summarise_by_interview(survey_coord(), hot_days(), interval = "1 year",
                           n_lags = 1)
}

# ==== Labels =================================================================

test_that("every kind of indicator gets a readable label", {
    out <- window_summary()
    labels <- c4e_labels(out)
    expect_snapshot(print(unname(labels[c("day_abv_30_sum", "C_abv_30_sum",
                                          "spell_abv_30_max", "spell_abv_30_n",
                                          "lag")])))

    long <- hot_days(1:60)
    pct <- calc_percentile(long, p = 0.9)
    rel <- suppressMessages(calc_percentile_day(long, pct))
    spi <- suppressMessages(
        extract_by_coord(read_climate(
            system.file("extdata", "pre_monthly.tif", package = "c4e")),
            georef_coord(survey_coord()))) |>
        calc_std_index(scale = 3) |>
        calc_std_threshold(below = -1.5)
    expect_snapshot({
        print(unname(c4e_labels(long)[c("value", "day_abv_30", "C_abv_30",
                                        "spell_abv_30")]))
        print(unname(c4e_labels(pct)["day_90p"]))
        print(unname(c4e_labels(rel)[c("day_abv_90p", "C_abv_90p")]))
        print(unname(c4e_labels(spi)[c("spi_3", "spi3_blw_-1.5")]))
    })
    expect_true(all(nchar(c4e_labels(out)) <= 80))
})

test_that("Stata names keep signs and decimals apart", {
    expect_equal(stata_names(c("spi3_blw_-1.5", "spi3_blw_-15", "spell_abv_0.1_90p",
                               "2021-01-01", "C_abv_30_sum")),
                 c("spi3_blw_m1p5", "spi3_blw_m15", "spell_abv_0p1_90p",
                   "X2021_01_01", "C_abv_30_sum"))
})

# ==== write_stata() ==========================================================

test_that("a window summary is written with labels Stata can read", {
    out <- window_summary()
    path <- withr::local_tempfile(fileext = ".dta")
    expect_snapshot(write_stata(out, path), transform = \(x) sub(" to .*$", " to <path>.", x))

    back <- haven::read_dta(path)
    expect_equal(nrow(back), 40L)
    expect_equal(as.numeric(back$day_abv_30_sum), out$day_abv_30_sum)
    expect_equal(attr(back$day_abv_30_sum, "label"),
                 unname(c4e_labels(out)["day_abv_30_sum"]))
    expect_equal(attr(back$hhid, "label"), NULL)
})

test_that("long tables keep their dates and write flags as 0/1", {
    long <- hot_days(182:212)   # July: days above 30 C occur
    path <- withr::local_tempfile(fileext = ".dta")
    suppressMessages(write_stata(long, path, labels = FALSE))
    back <- haven::read_dta(path)
    expect_s3_class(back$date, "Date")
    expect_setequal(unique(back$day_abv_30), c(0, 1))
    expect_null(attr(back$day_abv_30, "label"))
})

test_that("names Stata cannot take are refused before writing", {
    long <- dplyr::rename(hot_days(1:5),
                          a_very_long_indicator_name_beyond_stata_limits = day_abv_30)
    path <- withr::local_tempfile(fileext = ".dta")
    expect_snapshot(error = TRUE, write_stata(long, path))
    expect_false(file.exists(path))

    clash <- tibble::tibble(ID = "1", a.b = 1, a_b = 2)
    expect_error(write_stata(clash, path), "same Stata name")
})

test_that("a codebook lists every variable and the steps behind them", {
    out <- window_summary()
    path <- file.path(withr::local_tempdir(), "hot_days.dta")
    suppressMessages(write_stata(out, path, codebook = TRUE))
    codebook <- readLines(file.path(dirname(path), "hot_days_codebook.md"))

    expect_true(any(grepl("day_abv_30_sum", codebook)))
    expect_true(any(grepl(c4e_labels(out)[["spell_abv_30_max"]], codebook, fixed = TRUE)))
    expect_true(any(grepl("calc_threshold_day(above = 30", codebook, fixed = TRUE)))
    expect_true(any(grepl("summarise_by_interview(interval", codebook, fixed = TRUE)))
})

test_that("a plain data frame is written without labels", {
    path <- withr::local_tempfile(fileext = ".dta")
    suppressMessages(write_stata(data.frame(ID = c("1", "2"), x = 1:2), path))
    expect_equal(as.numeric(haven::read_dta(path)$x), c(1, 2))
})

# ==== validate_c4e() and summary() ===========================================

test_that("validation reports empty indicators, empty units and date gaps", {
    long <- hot_days(1:31)
    long$day_abv_30[long$ID == long$ID[1]] <- NA
    long$value[long$ID == long$ID[1]] <- NA
    long$C_abv_30[long$ID == long$ID[1]] <- NA
    long$spell_abv_30 <- NA_integer_
    long <- dplyr::filter(long, !(ID == ID[13] & date == as.Date("2021-01-10")))

    checks <- validate_c4e(long)
    expect_s3_class(checks, "c4e_checks")
    expect_equal(checks$status, c("ok", "problem", "problem", "problem"))
    expect_snapshot(print(checks))
})

test_that("a clean table passes validation", {
    checks <- validate_c4e(hot_days(182:212))   # July: spells above 30 C occur
    expect_true(all(checks$status == "ok"))
})

test_that("summary() describes the table, its indicators and its checks", {
    expect_snapshot(summary(window_summary()))
})
