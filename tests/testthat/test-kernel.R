# The matrix kernel (plan §8 chunk 6, §10.1, §13): every result must equal
# what the v1 long-format functions give on the synthetic fixtures.

extracted <- function(name = "tmax_daily.tif", layers = NULL) {
    raster <- suppressMessages(read_climate(
        system.file("extdata", name, package = "climatic4economist")))
    if (!is.null(layers)) raster <- raster[[layers]]
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    points <- georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
    extract_by_coord(raster, points)
}

# v1 output in a comparable shape: a tibble ordered by key and date
v1_long <- function(x, cols) {
    tibble::as_tibble(x) |>
        dplyr::select(dplyr::all_of(cols)) |>
        dplyr::arrange(ID, date)
}

# ==== Wide table to matrix and back ==========================================

test_that("a wide table becomes a units-by-dates matrix and back", {
    wide <- extracted(layers = 1:60)
    m <- as_matrix_wide(wide)

    expect_equal(dim(m$values), c(12L, 60L))
    expect_equal(m$ids$ID, sort(unique(wide$ID), method = "radix"))
    expect_equal(m$dates, as.Date("2021-01-01") + 0:59)

    long <- matrix_to_long(m$values, m$ids["ID"], m$dates)
    v1 <- find_extr_abs_day(wide)
    expect_equal(long, v1_long(v1, c("ID", "date", "value")))
})

test_that("date columns are put in calendar order", {
    wide <- tibble::tibble(ID = c("b", "a"), `2022-01-03` = 3:4,
                           `2022-01-01` = 1:2, `2022-01-02` = 5:6)
    m <- as_matrix_wide(wide)
    expect_equal(m$dates, as.Date("2022-01-01") + 0:2)
    expect_equal(m$values["a", ], c(2, 6, 4), ignore_attr = TRUE)
})

test_that("to_long() turns a wide c4e table into a long one with its context", {
    wide <- extracted(layers = 1:5)
    long <- to_long(wide)
    expect_true(is_c4e_tbl(long))
    expect_equal(c4e_meta(long, "shape"), "long")
    expect_equal(c4e_meta(long, "date_col"), "date")
    expect_equal(c4e_meta(long, "unit"), "K")
    expect_equal(nrow(long), 12L * 5L)
    expect_true(all(c("x_cell", "y_cell") %in% names(long)))
})

# ==== Absolute thresholds and spells =========================================

test_that("flags and excesses equal find_extr_abs_day()", {
    wide <- extracted()
    m <- as_matrix_wide(wide)
    v1 <- v1_long(find_extr_abs_day(wide, u_thresh = c(300, 305), l_thresh = 290,
                                    unit = "K"),
                  c("ID", "date", "day_abv_305", "K_abv_305", "day_blw_290",
                    "K_blw_290"))

    long <- matrix_to_long(
        m$values, m$ids["ID"], m$dates, value_name = NULL,
        extra = list(
            day_abv_305 = flag_threshold(m$values, 305, "above"),
            K_abv_305   = excess_threshold(m$values, 305, "above"),
            day_blw_290 = flag_threshold(m$values, 290, "below"),
            K_blw_290   = excess_threshold(m$values, 290, "below")
        ))
    expect_equal(long, v1)
})

test_that("spells equal find_spell()", {
    wide <- extracted()
    m <- as_matrix_wide(wide)
    v1 <- find_extr_abs_day(wide, u_thresh = 303, l_thresh = 293) |>
        find_spell(min_spell = 3) |>
        v1_long(c("ID", "date", "spell_abv_303", "spell_blw_293"))

    long <- matrix_to_long(
        m$values, m$ids["ID"], m$dates, value_name = NULL,
        extra = list(
            spell_abv_303 = run_length_rows(flag_threshold(m$values, 303, "above"), 3),
            spell_blw_293 = run_length_rows(flag_threshold(m$values, 293, "below"), 3)
        ))
    expect_equal(long, v1)
})

test_that("runs are counted per row, broken by FALSE and NA", {
    flags <- rbind(
        c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE),
        c(TRUE, NA, TRUE, TRUE, TRUE, TRUE),
        c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)
    )
    spells <- run_length_rows(flags, min_spell = 2)
    expect_equal(spells[1, ], c(NA, NA, 3L, NA, NA, 2L))
    expect_equal(spells[2, ], c(NA, NA, NA, NA, NA, 4L))
    expect_true(all(is.na(spells[3, ])))
    # a run never continues from the end of one row into the next
    expect_equal(run_length_rows(rbind(c(FALSE, TRUE), c(TRUE, FALSE)), 2)[2, 1],
                 NA_integer_)
    # each row matches compute_spell(), the v1 rule
    for (i in seq_len(nrow(flags))) {
        expect_equal(spells[i, ], compute_spell(flags[i, ], 2))
    }
})

# ==== Percentiles and relative thresholds ====================================

test_that("monthly percentiles equal calc_pct_day()", {
    wide <- extracted("pre_daily.tif")
    m <- as_matrix_wide(wide)
    pct <- quantile_by_month(m$values, m$dates, p = c(0.1, 0.9),
                             exclude_below = 0.1)

    v1 <- tibble::as_tibble(calc_pct_day(wide, p = c(0.1, 0.9), l_thresh = 0.1)) |>
        dplyr::arrange(ID, month)
    kernel <- tibble::tibble(
        ID      = rep(m$ids$ID, each = 12),
        month   = rep(sprintf("%02d", 1:12), times = nrow(m$ids)),
        day_10p = as.vector(t(pct[["10p"]])),
        day_90p = as.vector(t(pct[["90p"]]))
    )
    expect_equal(kernel, v1)
})

test_that("relative flags equal find_extr_rel_day()", {
    wide <- extracted()
    m <- as_matrix_wide(wide)
    pct <- quantile_by_month(m$values, m$dates, p = 0.9)
    threshold <- lookup_by_month(pct[["90p"]], m$dates)
    expect_equal(dim(threshold), dim(m$values))

    v1 <- find_extr_rel_day(wide, u_thresh = calc_pct_day(wide, p = 0.9),
                            unit = "K") |>
        v1_long(c("ID", "date", "day_abv_90p", "K_abv_90p"))
    long <- matrix_to_long(
        m$values, m$ids["ID"], m$dates, value_name = NULL,
        extra = list(day_abv_90p = flag_threshold(m$values, threshold, "above"),
                     K_abv_90p   = excess_threshold(m$values, threshold, "above")))
    expect_equal(long, v1)
})

test_that("percentiles of a unit with no data give the replacement", {
    m <- rbind(c(1, 2, 3), c(NA, NA, NA))
    dates <- as.Date("2022-01-01") + 0:2
    pct <- quantile_by_month(m, dates, p = 0.5, replace = 0)
    expect_equal(pct[["50p"]][, "01"], c(2, 0), ignore_attr = TRUE)
})

# ==== Standardised indices ===================================================

test_that("SPI from the matrix equals compute_spi()", {
    wide <- extracted("pre_monthly.tif")
    m <- as_matrix_wide(wide)
    spi <- spi_matrix(m$values, scale = 3)

    v1 <- compute_spi(tibble::as_tibble(wide), time_scale = 3) |>
        dplyr::arrange(ID)
    v1_values <- as.matrix(v1[grep(date_pattern(), names(v1))])
    expect_equal(unname(spi), unname(v1_values))
})

# ==== Rasters, block by block ================================================

test_that("a kernel runs over a raster block by block with the same numbers", {
    tmax <- suppressMessages(read_climate(
        system.file("extdata", "tmax_daily.tif", package = "climatic4economist")))[[1:30]]
    flags_of <- function(values) run_length_rows(flag_threshold(values, 300, "above"), 2)

    out <- apply_kernel_raster(tmax, flags_of, rows_per_block = 2)
    expect_equal(terra::nlyr(out), 30L)
    expect_equal(names(out), names(tmax))
    expect_equal(terra::values(out), flags_of(terra::values(tmax)),
                 ignore_attr = TRUE)

    # a kernel may return fewer layers, e.g. one summary per cell
    counts <- apply_kernel_raster(tmax, \(values) cbind(rowSums(values > 300)),
                                  names = "days_abv_300")
    expect_equal(names(counts), "days_abv_300")
    expect_equal(as.vector(terra::values(counts)), rowSums(terra::values(tmax) > 300))
})
