# Standardised indices and climatic parameters (plan §8 chunk 8)

extracted <- function(name, layers = NULL) {
    raster <- suppressMessages(read_climate(
        system.file("extdata", name, package = "c4e")))
    if (!is.null(layers)) raster <- raster[[layers]]
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    points <- georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
    extract_by_coord(raster, points)
}

# v1 wide output as a long table: ID, date, value
v1_long <- function(wide, value_name) {
    tibble::as_tibble(wide) |>
        dplyr::select(ID, dplyr::matches(date_pattern())) |>
        tidyr::pivot_longer(-ID, names_to = "date", values_to = value_name) |>
        dplyr::mutate(date = parse_date_label(to_date(date))) |>
        dplyr::arrange(ID, date)
}

# ==== calc_std_index() =======================================================

test_that("SPI equals compute_spi() and records its scale", {
    pre <- extracted("pre_monthly.tif")
    out <- calc_std_index(pre, scale = 3)

    v1 <- v1_long(compute_spi(tibble::as_tibble(pre), time_scale = 3), "spi_3")
    v2 <- tibble::as_tibble(out)[c("ID", "date", "spi_3")] |> dplyr::arrange(ID, date)
    expect_equal(v2, v1)

    meta <- c4e_meta(out)
    expect_equal(meta$shape, "long")
    expect_equal(meta$indicators$spi_3[c("kind", "index", "scale")],
                 list(kind = "std", index = "spi", scale = 3))
    expect_equal(meta$transform, list(index = "spi", scale = 3, base_variable = "pre"))
    expect_equal(c4e_history(out)$call[2], "calc_std_index(scale = 3, index = \"spi\")")
})

test_that("several scales give one column each", {
    out <- calc_std_index(extracted("pre_monthly.tif", layers = 1:120), scale = c(1, 6))
    expect_true(all(c("spi_1", "spi_6") %in% names(out)))
    expect_equal(c4e_meta(out)$transform$scale, c(1, 6))
    # the first five months of a six-month index are undefined
    first <- dplyr::filter(tibble::as_tibble(out), ID == ID[1]) |> dplyr::arrange(date)
    expect_true(all(is.na(first$spi_6[1:5])))
})

test_that("daily data are refused with a pointer to monthly aggregation", {
    expect_snapshot(error = TRUE,
                    calc_std_index(extracted("pre_daily.tif", layers = 1:90), scale = 3))
})

test_that("SPEI from precipitation and evapotranspiration equals compute_spei()", {
    pre <- extracted("pre_monthly.tif")
    pet <- dplyr::mutate(pre, dplyr::across(dplyr::matches(date_pattern()), \(v) v * 0 + 60))

    expect_snapshot(out <- calc_std_index(pre, scale = 3, index = "spei", pet = pet))
    balance <- dplyr::mutate(tibble::as_tibble(pre),
                             dplyr::across(dplyr::matches(date_pattern()), \(v) v - 60))
    v1 <- v1_long(compute_spei(balance, time_scale = 3), "spei_3")
    expect_equal(tibble::as_tibble(out)[c("ID", "date", "spei_3")] |>
                     dplyr::arrange(ID, date), v1)
    # evapotranspiration recorded with ERA5's negative sign gives the same balance
    pet_negative <- dplyr::mutate(pet, dplyr::across(dplyr::matches(date_pattern()), \(v) -v))
    out_negative <- suppressMessages(
        calc_std_index(pre, scale = 3, index = "spei", pet = pet_negative))
    expect_equal(out_negative$spei_3, out$spei_3)
})

test_that("SPEI without evapotranspiration takes x as the water balance", {
    balance <- extracted("pre_monthly.tif", layers = 1:120) |>
        dplyr::mutate(dplyr::across(dplyr::matches(date_pattern()), \(v) v - 60))
    expect_message(out <- calc_std_index(balance, scale = 1, index = "spei"),
                   "water balance")
    expect_true("spei_1" %in% names(out))
})

# ==== calc_std_threshold() ===================================================

test_that("index thresholds keep their sign and equal extr_std_index()", {
    spi <- calc_std_index(extracted("pre_monthly.tif"), scale = 3)
    out <- calc_std_threshold(spi, below = c(-1, -1.5), above = 1.5)

    expect_true(all(c("spi3_blw_-1", "spi3_blw_-1.5", "spi3_abv_1.5") %in% names(out)))
    v1 <- tibble::as_tibble(spi) |>
        dplyr::transmute(value = spi_3) |>
        extr_std_index(l_thrshld = c(-1, -1.5), u_thrshld = 1.5)
    expect_equal(out[["spi3_blw_-1.5"]], v1$std_blw_1.5)
    expect_equal(out[["spi3_abv_1.5"]], v1$std_abv_1.5)

    entry <- c4e_meta(out)$indicators[["spi3_blw_-1.5"]]
    expect_equal(entry[c("kind", "base", "direction", "threshold", "index", "scale")],
                 list(kind = "flag", base = "spi_3", direction = "below",
                      threshold = -1.5, index = "spi", scale = 3))
})

test_that("drought months chain into spells", {
    out <- calc_std_index(extracted("pre_monthly.tif"), scale = 3) |>
        calc_std_threshold(below = -1) |>
        calc_spell(min_spell = 2)
    expect_true("spell_spi3_blw_-1" %in% names(out))
    expect_equal(c4e_meta(out)$indicators[["spell_spi3_blw_-1"]]$base, "spi3_blw_-1")
})

test_that("thresholds need a standardised index to work on", {
    expect_error(calc_std_threshold(extracted("pre_monthly.tif", layers = 1:12),
                                    below = -1),
                 "calc_std_index")
})

# ==== calc_par() on the fixtures, against v1 =================================

test_that("climatic parameters equal the v1 results on the fixtures", {
    reference <- readRDS(test_path("fixtures", "v1_calc_par.rds"))
    # the references were saved with v1's sequential IDs; locations are
    # matched by their cell coordinates, which do not depend on the ID rule
    same <- function(v2, v1) {
        cols <- setdiff(names(v1), "ID")
        expect_equal(dplyr::arrange(tibble::as_tibble(v2)[cols], x_cell, y_cell),
                     dplyr::arrange(tibble::as_tibble(v1)[cols], x_cell, y_cell))
    }
    tmax <- extracted("tmax_daily.tif")
    pre  <- extracted("pre_daily.tif")

    same(calc_par(tmax, fn = list(avg = mean, sd = stats::sd), prefix = FALSE),
         reference$tmax_all)
    same(calc_par(pre, fn = list(total = sum), period = "year", prefix = FALSE),
         reference$pre_year)
    same(calc_par(pre, fn = list(total = sum, wet = \(x) sum(x > 1)),
                  period = "month", prefix = FALSE),
         reference$pre_month)
    expect_warning(
        monthly <- calc_par(extracted("pre_monthly.tif"), fn = list(avg = mean),
                            period = "year", prefix = FALSE),
        "not the last day of a month")
    same(monthly, reference$pre_monthly_year)
})

test_that("parameters are named after the variable and registered", {
    expect_snapshot(out <- calc_par(extracted("tmax_daily.tif"), fn = c("mean", "sd")))
    expect_true(all(c("tmax_mean", "tmax_sd") %in% names(out)))
    meta <- c4e_meta(out)
    expect_equal(meta$shape, "summary")
    expect_equal(meta$indicators$tmax_mean[c("kind", "stat", "period")],
                 list(kind = "par", stat = "mean", period = "all"))
    expect_equal(meta$indicators$tmax_sd$unit, "K")
})

test_that("monthly data asked for monthly aggregation is refused at once", {
    expect_error(calc_par(extracted("pre_monthly.tif"), fn = list(total = sum),
                          period = "month"),
                 "already at monthly resolution")
})
