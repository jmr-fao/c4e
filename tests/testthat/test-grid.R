# Grid methods and wrappers (plan §8 chunk 12, §13)

fixture_file <- function(name) system.file("extdata", name, package = "c4e")
quiet <- function(expr) suppressMessages(expr)

survey_points <- function() {
    coord <- prepare_coord(synthetic_survey(), lat, lon, id = hhid,
                           interview = interview)
    quiet(georef_coord(coord))
}
tmax_raster <- function() quiet(read_climate(fixture_file("tmax_daily.tif")))

# ==== grid_indicators() ======================================================

test_that("grid indicators extracted at points equal the table path", {
    grid <- quiet(grid_indicators(fixture_file("tmax_daily.tif"), preset = "heat"))
    expect_s4_class(grid, "SpatRaster")
    expect_true(all(c("day_abv_30_sum_2021", "spell_abv_35_max_2023") %in% names(grid)))
    expect_equal(unique(terra::units(grid[["day_abv_30_sum_2021"]])), "days")
    expect_equal(unique(terra::units(grid[["C_abv_30_sum_2021"]])), "C")

    points <- survey_points()
    from_grid <- quiet(extract_by_coord(grid, points))
    from_table <- quiet(
        extract_by_coord(tmax_raster(), points) |>
            convert_unit("C") |>
            calc_threshold_day(above = c(30, 35)) |>
            calc_spell(min_spell = 2) |>
            summarise_by_period("year"))
    expect_equal(tibble::as_tibble(from_grid), tibble::as_tibble(from_table))

    meta <- c4e_meta(from_grid)
    expect_equal(meta$date_col, "period")
    expect_equal(meta$time_step, "year")
    expect_equal(meta$unit, "C")
    expect_setequal(names(meta$indicators), names(c4e_meta(from_table)$indicators))
    entry <- meta$indicators$day_abv_30_sum
    expect_equal(entry[c("kind", "stat", "threshold", "direction", "period")],
                 list(kind = "agg", stat = "sum", threshold = 30, direction = "above",
                      period = "year"))
    expect_match(c4e_history(from_grid)$call[1], "^grid_indicators\\(preset = \"heat\"")
})

test_that("blocks of rows give the same raster as one block", {
    withr::local_options(c4e.grid_fast = FALSE)
    whole <- quiet(grid_indicators(fixture_file("tmax_daily.tif"), above = 30,
                                   spells = FALSE))
    withr::local_options(c4e.grid_rows = 1)
    blocks <- quiet(grid_indicators(fixture_file("tmax_daily.tif"), above = 30,
                                    spells = FALSE))
    expect_equal(terra::values(blocks), terra::values(whole))
    expect_equal(names(blocks), names(whole))
})

test_that("the tapp() fast path gives the block engine's raster", {
    tmax <- tmax_raster()
    tmax[1:6] <- NA
    tmax[[1:200]][7:12] <- NA        # a first year short of days in some cells
    run <- function() {
        list(grid = quiet(grid_indicators(tmax, above = c(30, 33), below = 285,
                                          unit = "K", spells = FALSE,
                                          control = extremes_control(min_coverage = 0.6))),
             method = quiet(calc_threshold_day(tmax, below = 290, period = "month")))
    }
    fast <- run()
    withr::local_options(c4e.grid_fast = FALSE)
    engine <- run()
    for (name in names(fast)) {
        expect_equal(names(fast[[name]]), names(engine[[name]]), label = name)
        expect_equal(terra::values(fast[[name]]), terra::values(engine[[name]]),
                     label = name)
        expect_equal(read_grid_meta(fast[[name]])$entries,
                     read_grid_meta(engine[[name]])$entries, label = name)
    }
    expect_true(all(is.na(terra::values(fast$grid[["day_abv_30_sum_2021"]])[7:12])))
})

test_that("a grid written to GeoTIFF restores its registry when extracted", {
    path <- withr::local_tempfile(fileext = ".tif")
    withr::local_options(c4e.mem_limit = "20KB")
    written <- quiet(grid_indicators(fixture_file("tmax_daily.tif"), preset = "heat",
                                     filename = path))
    expect_true(file.exists(path))
    expect_error(grid_indicators(fixture_file("tmax_daily.tif"), preset = "heat",
                                 filename = path), "exists")

    read_back <- terra::rast(path)
    points <- survey_points()
    from_file <- quiet(extract_by_coord(read_back, points))
    in_memory <- quiet(extract_by_coord(
        grid_indicators(fixture_file("tmax_daily.tif"), preset = "heat"), points))
    expect_equal(tibble::as_tibble(from_file), tibble::as_tibble(in_memory),
                 tolerance = 1e-5)
    expect_equal(c4e_meta(from_file)$indicators, c4e_meta(in_memory)$indicators)
})

test_that("cells with no data stay empty", {
    tmax <- tmax_raster()
    tmax[1:6] <- NA
    grid <- quiet(grid_indicators(tmax, above = 30, spells = FALSE))
    values <- terra::values(grid[["day_abv_30_sum_2021"]])
    expect_true(all(is.na(values[1:6])))
    expect_false(anyNA(values[-(1:6)]))
})

test_that("grid_indicators checks its input and supports dry runs", {
    expect_error(grid_indicators(fixture_file("pre_daily.tif"), preset = "heat"),
                 "expects daily tmax")
    table <- quiet(extract_by_coord(tmax_raster(), survey_points()))
    expect_error(grid_indicators(table, above = 30), "need a raster")
    expect_null(quiet(grid_indicators(fixture_file("tmax_daily.tif"), preset = "heat",
                                      control = extremes_control(dry_run = TRUE))))
    empty <- tmax_raster()
    empty[] <- NA
    expect_error(quiet(grid_indicators(empty, above = 30)), "No cell")
})

test_that("monthly periods name layers by month", {
    grid <- quiet(grid_indicators(fixture_file("pre_daily.tif"), preset = "heavy_rain",
                                  period = "month", spells = FALSE))
    expect_true("day_abv_20_sum_2021-07" %in% names(grid))
    expect_equal(terra::nlyr(grid), 2 * 2 * 36)
})

# ==== Raster methods of the step functions ===================================

test_that("calc_threshold_day() on a raster counts days per period", {
    tmax <- convert_unit(tmax_raster(), "C")
    grid <- quiet(calc_threshold_day(tmax, above = 30))
    expect_equal(names(grid)[1], "day_abv_30_sum_2021")

    points <- survey_points()
    from_grid <- quiet(extract_by_coord(grid, points))
    from_table <- quiet(extract_by_coord(tmax, points) |>
                            calc_threshold_day(above = 30) |>
                            summarise_by_period("year"))
    expect_equal(tibble::as_tibble(from_grid), tibble::as_tibble(from_table))
})

test_that("calc_par() on a raster gives each cell's statistics", {
    tmax <- tmax_raster()
    grid <- quiet(calc_par(tmax, fn = c("mean", "sd")))
    expect_equal(names(grid), c("tmax_mean", "tmax_sd"))

    points <- survey_points()
    from_grid <- quiet(extract_by_coord(grid, points))
    from_table <- quiet(calc_par(extract_by_coord(tmax, points), fn = c("mean", "sd")))
    expect_equal(tibble::as_tibble(from_grid), tibble::as_tibble(from_table))
    expect_equal(c4e_meta(from_grid)$shape, "summary")

    celsius <- convert_unit(tmax, "C")
    expect_message(calc_par(celsius, fn = "cv"), "kelvin")
})

test_that("calc_std_index() on a raster gives the monthly index per cell", {
    pre <- quiet(read_climate(fixture_file("pre_monthly.tif")))
    grid <- quiet(calc_std_index(pre, scale = 3))
    expect_equal(terra::nlyr(grid), terra::nlyr(pre))
    expect_true(all(startsWith(names(grid), "spi_3_")))

    points <- survey_points()
    from_grid <- quiet(extract_by_coord(grid, points))
    from_table <- quiet(calc_std_index(extract_by_coord(pre, points), scale = 3))
    expect_equal(from_grid$spi_3, from_table$spi_3)
    expect_equal(c4e_meta(from_grid)$indicators$spi_3$index, "spi")
})

test_that("calc_percentile() on a raster gives monthly percentiles per cell", {
    tmax <- tmax_raster()
    grid <- quiet(calc_percentile(tmax, p = 0.9))
    expect_equal(names(grid), sprintf("day_90p_%02d", 1:12))

    points <- survey_points()
    from_grid <- quiet(extract_by_coord(grid, points))
    from_table <- quiet(calc_percentile(extract_by_coord(tmax, points), p = 0.9))
    expect_equal(from_grid$day_90p, from_table$day_90p)
    expect_equal(from_grid$month, from_table$month)
    expect_equal(c4e_meta(from_grid)$shape, "lookup")
})

test_that("the table methods reject unknown arguments", {
    df <- data.frame(ID = "1", `2001-01-01` = 1, `2001-02-01` = 2, check.names = FALSE)
    expect_error(calc_par(df, fn = mean, prefx = "a"), "must be empty")
})

# ==== grid_controls() ========================================================

pop_raster <- function() {
    template <- terra::rast(fixture_file("tmax_daily.tif"))[[1]]
    pop <- terra::rast(template, vals = seq(100, 3600, by = 100))
    terra::time(pop) <- NULL
    pop
}

test_that("population density is people per km2 within each radius", {
    pop <- pop_raster()
    grid <- quiet(grid_controls(pop = pop, radius_m = c(0, 50000)))
    expect_equal(names(grid), c("pop_density", "pop_density_50km"))

    area <- terra::cellSize(pop, unit = "km")
    expect_equal(terra::values(grid[["pop_density"]]), terra::values(pop / area),
                 ignore_attr = TRUE)

    w <- circle_window(pop, 50000)
    expect_gt(sum(w), 1)
    manual <- terra::focal(pop, w, fun = "sum", na.rm = TRUE) /
        terra::focal(area, w, fun = "sum", na.rm = TRUE)
    expect_equal(terra::values(grid[["pop_density_50km"]]), terra::values(manual),
                 ignore_attr = TRUE)

    points <- survey_points()
    extracted <- quiet(extract_by_coord(grid, points))
    expect_equal(c4e_meta(extracted)$indicators$pop_density_50km$stat, "density")
    expect_match(c4e_labels(extracted)[["pop_density_50km"]], "within 50 km")
})

test_that("grid_controls adds climate normals and other layers", {
    template <- terra::rast(fixture_file("tmax_daily.tif"))[[1]]
    zones <- terra::rast(template, vals = rep(c(1, 2, 3), 12))
    terra::time(zones) <- NULL
    expect_message(
        grid <- grid_controls(pop = pop_raster(), radius_m = 0,
                              climate = list(tmax = fixture_file("tmax_daily.tif")),
                              years = 2, stats = c("mean", "sd"),
                              layers = list(aez = zones)),
        "grid_controls")
    expect_equal(names(grid), c("pop_density", "tmax_mean", "tmax_sd", "aez"))

    tmax <- tmax_raster()
    last_two <- select_by_dates(tmax, from = as.Date("2022-01-01"),
                                to = as.Date("2023-12-31"))
    expect_equal(terra::values(grid[["tmax_mean"]]),
                 terra::values(terra::app(last_two, mean)), ignore_attr = TRUE)
    expect_true(all(terra::values(grid[["aez"]]) %in% 1:3))

    coarse <- quiet(grid_controls(layers = list(aez = zones), fact = 2))
    expect_equal(terra::ncell(coarse), 9)
    expect_true(all(terra::values(coarse) %in% 1:3))
})
