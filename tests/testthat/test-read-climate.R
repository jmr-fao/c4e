# Raster readers: read_climate(), raster metadata, aggregate_time(),
# raster selection, read_boundaries() (plan §2, §9.4, §9.5, §11.7)

fixture_file <- function(name) {
    system.file("extdata", name, package = "c4e")
}

# write a small raster with the given layer names, units and time to a file
write_test_raster <- function(file, nlyr = 3, names = NULL, units = NULL,
                              time = NULL, xmin = 30, xmax = 31, vals = NULL) {
    r <- terra::rast(nrows = 2, ncols = 2, nlyrs = nlyr, xmin = xmin,
                     xmax = xmax, ymin = 0, ymax = 1, crs = "EPSG:4326",
                     vals = vals %||% seq_len(4 * nlyr))
    if (!is.null(names)) names(r) <- names
    if (!is.null(units)) terra::units(r) <- units
    if (!is.null(time)) terra::time(r) <- time
    terra::writeRaster(r, file, overwrite = TRUE)
    file
}

# ==== Raster metadata ========================================================

test_that("raster metadata survives in-memory steps and files", {
    r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 3, vals = 1:12)
    r <- set_raster_meta(r, list(variable = "tmax", kind = "continuous",
                                 source = "era5", label = "test"))

    expect_equal(raster_meta(r)$variable, "tmax")
    expect_equal(terra::varnames(r), "tmax")
    # subsetting and arithmetic keep it in memory ...
    expect_equal(raster_meta(r[[1:2]])$source, "era5")
    expect_equal(raster_meta(r * 2)$label, "test")
    # ... and a GeoTIFF keeps it on disk
    file <- withr::local_tempfile(fileext = ".tif")
    terra::writeRaster(r, file)
    expect_equal(raster_meta(terra::rast(file))$variable, "tmax")
})

test_that("a raster without package metadata gives empty metadata", {
    meta <- raster_meta(terra::rast(nrows = 1, ncols = 1, vals = 1))
    expect_null(meta$variable)
    expect_null(meta$kind)
})

# ==== read_climate() on the fixtures =========================================

test_that("the fixtures read with dates, units and variable", {
    tmax <- read_climate(fixture_file("tmax_daily.tif"))

    expect_equal(terra::nlyr(tmax), 1095)
    expect_equal(range(terra::time(tmax)), as.Date(c("2021-01-01", "2023-12-31")))
    expect_equal(unique(terra::units(tmax)), "K")
    expect_equal(terra::varnames(tmax), "tmax")
    expect_equal(names(tmax)[1:2], c("2021-01-01", "2021-01-02"))

    meta <- raster_meta(tmax)
    expect_equal(meta$variable, "tmax")
    expect_equal(meta$time_step, "day")
    expect_equal(meta$kind, "continuous")
    expect_equal(meta$label, "tmax_daily")

    pre_month <- read_climate(fixture_file("pre_monthly.tif"))
    expect_equal(raster_meta(pre_month)$time_step, "month")
    expect_equal(raster_meta(pre_month)$variable, "pre")
    expect_equal(unique(terra::units(pre_month)), "mm/month")
})

test_that("reading announces what was found", {
    expect_snapshot(invisible(read_climate(fixture_file("pre_daily.tif"))))
})

test_that("explicit arguments override what the file says", {
    r <- read_climate(fixture_file("tmax_daily.tif"), variable = "tmean",
                      unit = "degC", label = "Mali22")
    meta <- raster_meta(r)
    expect_equal(meta$variable, "tmean")
    expect_equal(meta$label, "Mali22")
    expect_equal(unique(terra::units(r)), "C")
})

# ==== Conventions of other sources ===========================================

test_that("ERA5 layer names give the variable and the dates", {
    seconds <- as.numeric(as.POSIXct("2024-01-01", tz = "UTC")) + 86400 * 0:2
    file <- write_test_raster(
        file.path(withr::local_tempdir(), "era5_daily.tif"),
        names = paste0("t2m_valid_time=", seconds), units = "K")

    r <- suppressMessages(read_climate(file))
    expect_equal(terra::time(r), as.Date("2024-01-01") + 0:2)
    expect_equal(raster_meta(r)$variable, "tmean")
    expect_equal(raster_meta(r)$source, "era5")
})

test_that("CHIRPS files take their dates from the file names", {
    dir <- withr::local_tempdir()
    files <- vapply(c("2021.01", "2021.02", "2021.03"), \(m) {
        write_test_raster(file.path(dir, paste0("chirps-v2.0.", m, ".tif")), nlyr = 1)
    }, character(1))

    r <- suppressMessages(read_climate(files))
    expect_equal(terra::time(r), as.Date(c("2021-01-01", "2021-02-01", "2021-03-01")))
    meta <- raster_meta(r)
    expect_equal(meta$variable, "pre")
    expect_equal(meta$source, "chirps")
    expect_equal(meta$time_step, "month")
    expect_equal(unique(terra::units(r)), "mm/month")
})

test_that("GAEZ zones are read as a static categorical layer", {
    file <- write_test_raster(
        file.path(withr::local_tempdir(), "GAEZ_V5_AEZ33_10km.tif"), nlyr = 1)
    r <- suppressMessages(read_climate(file))
    meta <- raster_meta(r)
    expect_equal(meta$kind, "categorical")
    expect_equal(meta$variable, "aez")
    expect_null(meta$time_step)
})

test_that("a plain file is understood from its name and layer dates", {
    file <- write_test_raster(
        file.path(withr::local_tempdir(), "tmin_2022.tif"),
        names = c("2022-01-01", "2022-01-02", "2022-01-03"), units = "degC")
    r <- suppressMessages(read_climate(file))
    expect_equal(terra::time(r), as.Date("2022-01-01") + 0:2)
    expect_equal(raster_meta(r)$variable, "tmin")
    expect_equal(unique(terra::units(r)), "C")
})

test_that("projects can register their own source", {
    withr::defer(reset_sources())
    register_source(
        "agera5",
        detect   = "AgERA5",
        variable = "tmax",
        unit     = "C",
        time     = function(x, files) as.Date("2020-01-01") + seq_len(terra::nlyr(x)) - 1
    )
    file <- write_test_raster(file.path(withr::local_tempdir(), "AgERA5_tmax.tif"))
    r <- suppressMessages(read_climate(file))
    expect_equal(raster_meta(r)$source, "agera5")
    expect_equal(terra::time(r)[1], as.Date("2020-01-01"))
    expect_equal(unique(terra::units(r)), "C")
    expect_true("agera5" %in% list_sources())
})

# ==== Cleaning while reading =================================================

test_that("0-360 longitudes are rotated to -180-180", {
    file <- write_test_raster(file.path(withr::local_tempdir(), "pre_global.tif"),
                              nlyr = 1, xmin = 0, xmax = 360)
    expect_message(r <- read_climate(file, variable = "pre"), "Rotating")
    expect_equal(terra::xmin(r), -180)
    expect_equal(raster_meta(r)$variable, "pre")
})

test_that("no-data codes become NA", {
    file <- write_test_raster(file.path(withr::local_tempdir(), "urca.tif"),
                              nlyr = 1, vals = c(1, 128, 3, 128))
    r <- suppressMessages(read_climate(file, na_value = 128))
    expect_equal(as.vector(terra::values(r)), c(1, NA, 3, NA))
    expect_equal(raster_meta(r)$kind, "categorical")
})

# ==== aggregate_time() =======================================================

test_that("daily precipitation sums to months with valid date names", {
    pre <- read_climate(fixture_file("pre_daily.tif"))[[1:59]]   # Jan-Feb 2021
    expect_snapshot(monthly <- aggregate_time(pre, "month"))

    expect_equal(names(monthly), c("2021-01-01", "2021-02-01"))
    expect_equal(terra::time(monthly), as.Date(c("2021-01-01", "2021-02-01")))
    expect_equal(terra::values(monthly)[, 1],
                 rowSums(terra::values(pre)[, 1:31]))
    expect_equal(unique(terra::units(monthly)), "mm/month")
    expect_equal(raster_meta(monthly)$time_step, "month")
})

test_that("temperature averages by default, and fn can be chosen", {
    tmax <- read_climate(fixture_file("tmax_daily.tif"))[[1:365]]
    yearly <- suppressMessages(aggregate_time(tmax, "year"))
    expect_equal(terra::values(yearly)[, 1], rowMeans(terra::values(tmax)))
    expect_equal(unique(terra::units(yearly)), "K")

    hottest <- aggregate_time(tmax, "month", fn = "max")
    expect_equal(terra::values(hottest)[, 1],
                 apply(terra::values(tmax)[, 1:31], 1, max))
})

test_that("aggregation needs dates and a coarser target step", {
    tmax <- read_climate(fixture_file("tmax_daily.tif"))[[1:31]]
    expect_error(aggregate_time(tmax, "day"), "coarser")
    expect_error(aggregate_time(terra::rast(nrows = 1, ncols = 1, nlyrs = 2,
                                            vals = 1:2), "month"),
                 "dates")
})

# ==== select_by_dates() and select_by_season() on rasters ====================

test_that("rasters are selected by date and by season", {
    tmax <- read_climate(fixture_file("tmax_daily.tif"))

    out <- select_by_dates(tmax, from = "2022-01-01", to = "2022-12-31")
    expect_equal(terra::nlyr(out), 365)
    expect_equal(raster_meta(out)$variable, "tmax")

    winter <- select_by_season(tmax, "Dec", "Feb")
    months <- as.integer(format(terra::time(winter), "%m"))
    expect_setequal(unique(months), c(12, 1, 2))
    expect_equal(raster_meta(winter)$label, "tmax_daily")
})

test_that("selecting columns of a c4e table updates its date range", {
    wide <- update_meta(
        tibble::tibble(ID = "1", `2022-01-01` = 1, `2022-06-01` = 2,
                       `2022-12-01` = 3),
        key = "ID", shape = "wide",
        date_range = as.Date(c("2022-01-01", "2022-12-01")))
    out <- select_by_dates(wide, from = "2022-03-01")
    expect_equal(names(out), c("ID", "2022-06-01", "2022-12-01"))
    expect_equal(c4e_meta(out, "date_range"), as.Date(c("2022-06-01", "2022-12-01")))
})

test_that("a column that only contains a year is not taken for a date", {
    # the old unanchored pattern treated MAX_2020 as a date column
    df <- data.frame(ID = "1", MAX_2020 = 9, X2022.01 = 1, X2022.02 = 2)
    out <- select_by_dates(df, from = "2022-02")
    expect_equal(names(out), c("ID", "MAX_2020", "X2022.02"))
})

# ==== read_boundaries() ======================================================

test_that("read_boundaries() reads either source with the same arguments", {
    root <- withr::local_tempdir()
    make_gaul_tree(root, "KEN", lvl = 2, n = 3)
    gaul <- read_boundaries(root, iso = "KEN", level = 2, source = "gaul")
    expect_s4_class(gaul, "SpatVector")
    expect_true(all(c("ID_adm_div", "adm_div_1", "adm_div_2") %in% names(gaul)))

    root2 <- withr::local_tempdir()
    make_boundary_tree(root2, "KEN", n_adm1 = 2)
    gb <- read_boundaries(root2, iso = "KEN", level = 1, source = "geoboundaries")
    expect_equal(nrow(gb), 2L)
    expect_error(read_boundaries(root, "KEN", source = "osm"), "source")
})
