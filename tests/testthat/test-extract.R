# Extraction returns c4e tables with their context (plan §8 chunk 5, §9.5,
# §10.4, §11.6, §14)

fixture_raster <- function(name = "tmax_daily.tif") {
    suppressMessages(read_climate(
        system.file("extdata", name, package = "c4e")))
}
fixture_points <- function() {
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
}

# ==== extract_by_coord() =====================================================

test_that("point extraction records the raster's context", {
    tmax <- fixture_raster()[[1:10]]
    out  <- extract_by_coord(tmax, fixture_points())

    expect_true(is_c4e_tbl(out))
    meta <- c4e_meta(out)
    expect_equal(meta$key, "ID")
    expect_equal(meta$unit_cols, c("x_cell", "y_cell"))
    expect_equal(meta$variable, "tmax")
    expect_equal(meta$unit, "K")
    expect_equal(meta$time_step, "day")
    expect_equal(meta$shape, "wide")
    expect_equal(meta$date_range, as.Date(c("2021-01-01", "2021-01-10")))
    expect_equal(meta$crs, "EPSG:4326")
    expect_equal(meta$source, "synthetic")
    expect_equal(meta$label, "tmax_daily")
    expect_equal(meta$spatial_agg$level, "point")
    expect_equal(c4e_history(out)$call, "extract_by_coord()")
    expect_equal(nrow(out), 12L)
    expect_true(all(c("2021-01-01", "2021-01-10") %in% names(out)))
})

test_that("points in another CRS than the raster are refused", {
    points <- terra::project(fixture_points(), "EPSG:3857")
    expect_snapshot(error = TRUE, extract_by_coord(fixture_raster()[[1]], points))

    bare <- terra::vect(data.frame(ID = "1", x = 30.5, y = -0.5), geom = c("x", "y"))
    expect_error(extract_by_coord(fixture_raster()[[1]], bare), "no CRS")
})

test_that("locations without data are reported", {
    tmax <- fixture_raster()[[1:3]]
    tmax[1] <- NA                                   # top-left cell, every layer
    points <- terra::vect(
        data.frame(ID = c("in", "outside", "missing"),
                   lon = c(30.5, 35, 30.05), lat = c(-0.5, -0.5, 0.15)),
        geom = c("lon", "lat"), crs = "EPSG:4326")

    expect_snapshot(out <- extract_by_coord(tmax, points))
    expect_equal(nrow(out), 3L)
})

test_that("a buffer summarises the cells around each location", {
    tmax   <- fixture_raster()[[1:3]]
    points <- fixture_points()
    out <- extract_by_coord(tmax, points, buffer = 20000)

    zones <- terra::buffer(points, width = 20000)
    expected <- terra::extract(tmax, zones, fun = mean, na.rm = TRUE, ID = FALSE)
    expect_equal(out[["2021-01-02"]], expected[["2021-01-02"]])
    expect_equal(c4e_meta(out)$spatial_agg,
                 list(level = "buffer", fn = "mean", buffer = 20000))
    expect_null(c4e_meta(out, "unit_cols"))
})

test_that("large extractions run in blocks of layers with the same result", {
    tmax   <- fixture_raster()[[1:40]]
    points <- fixture_points()
    whole  <- extract_by_coord(tmax, points)

    withr::local_options(c4e.mem_limit = 12 * 40 * 8 / 3)
    expect_snapshot(split <- extract_by_coord(tmax, points))
    expect_equal(tibble::as_tibble(split), tibble::as_tibble(whole))

    withr::local_options(c4e.mem_limit = NULL)
    forced <- suppressMessages(extract_by_coord(tmax, points, chunk = 15))
    expect_equal(tibble::as_tibble(forced), tibble::as_tibble(whole))
})

test_that("a static raster gives a summary table", {
    elevation <- terra::rast(fixture_raster()[[1]], vals = 1:36)
    names(elevation) <- "elevation"
    out <- extract_by_coord(elevation, fixture_points())
    expect_equal(c4e_meta(out, "shape"), "summary")
    expect_null(c4e_meta(out, "date_range"))
})

# ==== extract_by_poly() ======================================================

test_that("polygon extraction records its context and the key", {
    adm_div <- synthetic_adm_div()
    out <- extract_by_poly(fixture_raster()[[1:5]], adm_div)

    meta <- c4e_meta(out)
    expect_equal(meta$key, "ID_adm_div")
    expect_equal(meta$variable, "tmax")
    expect_equal(meta$spatial_agg, list(level = "poly", fn = "mean"))
    expect_equal(nrow(out), 3L)
    expect_true(all(c("adm_div_1", "adm_div_2") %in% names(out)))
})

test_that("the summary follows the kind of variable, and is announced", {
    zones <- terra::rast(fixture_raster()[[1]], vals = rep(c(1, 2, 2), 12))
    names(zones) <- "aez"
    zones <- suppressMessages(read_climate(zones, variable = "aez"))
    expect_snapshot(out <- extract_by_poly(zones, synthetic_adm_div()))
    expect_equal(c4e_meta(out)$spatial_agg$fn, "mode")
    expect_true(all(out$aez %in% c(1, 2)))
})

test_that("coverage weights give exactextractr's area-weighted mean", {
    tmax <- fixture_raster()[[1:2]]
    adm_div <- synthetic_adm_div()
    out <- extract_by_poly(tmax, adm_div, weights = "coverage")

    expected <- exactextractr::exact_extract(tmax, sf::st_as_sf(adm_div), "mean",
                                             progress = FALSE)
    expect_equal(out[["2021-01-01"]], expected[[1]])
    expect_equal(c4e_meta(out)$spatial_agg$weights, "coverage")
})

test_that("polygons in another CRS are refused", {
    adm_div <- terra::project(synthetic_adm_div(), "EPSG:3857")
    expect_error(extract_by_poly(fixture_raster()[[1]], adm_div), "different CRS")
})

# ==== extract_cell_by_poly() =================================================

test_that("cells are keyed by the division's own identifier", {
    adm_div <- synthetic_adm_div()
    adm_div$ID_adm_div <- c("10", "20", "30")
    out <- extract_cell_by_poly(fixture_raster()[[1:3]], adm_div)

    expect_setequal(unique(out$ID_adm_div), c("10", "20", "30"))
    meta <- c4e_meta(out)
    expect_equal(meta$key, "ID_adm_div")
    expect_equal(meta$unit_cols, c("x_cell", "y_cell", "coverage_fraction"))
    expect_equal(meta$spatial_agg$level, "cell")
    expect_equal(names(out)[1:4],
                 c("ID_adm_div", "x_cell", "y_cell", "coverage_fraction"))
})

test_that("cell extraction in blocks of layers gives the same result", {
    tmax <- fixture_raster()[[1:30]]
    adm_div <- synthetic_adm_div()
    whole <- extract_cell_by_poly(tmax, adm_div)
    forced <- suppressMessages(extract_cell_by_poly(tmax, adm_div, chunk = 7))
    expect_equal(tibble::as_tibble(forced), tibble::as_tibble(whole))
})

# ==== extract_weighted_by_poly() =============================================

test_that("weighted extraction records its weights", {
    out <- extract_weighted_by_poly(fixture_raster()[[1:2]], synthetic_adm_div())
    meta <- c4e_meta(out)
    expect_equal(meta$key, "ID_adm_div")
    expect_equal(meta$unit, "K")
    expect_equal(meta$spatial_agg, list(level = "poly", fn = "mean", weights = "area"))
})
