# Settings for dev/compare/compare-v1.R on your own data.
#
# Copy this file to dev/compare/config-local.R (ignored by git), fill in the
# paths and run, from the package root:
#   Rscript dev/compare/compare-v1.R dev/compare/config-local.R
# Fields left out keep the defaults at the top of compare-v1.R. The data are
# only read; the report goes to `out_dir`.

config <- list(
    name = "my survey",
    # survey: .dta, .csv or .rds, one row per household
    survey = "path/to/survey/household.dta",
    id = "hhid", lat = "lat", lon = "lon", interview = "interview_date",
    # daily raster with dates in terra::time(), e.g. ERA5-Land 2 m maximum temperature
    daily = "path/to/weather/tmax_daily.nc",
    daily_to_unit = "C",
    from = "1991-01-01", to = "2017-12-31",
    above = c(30, 35), below = NULL,
    min_spell = 2,
    p = c(0.1, 0.9), exclude_below = NULL,
    heatwave = TRUE,
    interval = "1 year", n_lags = 2,
    # monthly precipitation for SPI; NULL to skip
    monthly = "path/to/weather/pre_monthly.nc",
    scale = c(1, 3, 6),
    # administrative divisions for the cell extraction; NULL to skip
    boundaries = "path/to/adm_div/adm2.gpkg",
    out_dir = "dev/compare/out"
)
