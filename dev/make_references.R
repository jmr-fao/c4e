# Save the outputs of v1 functions on the synthetic fixtures, before c4e
# replaces or removes them, so the tests can keep checking that the new
# functions give the same numbers (plan §8 chunk 13, decided at the rename).
#
# Run from the package root, on the commit where the v1 function still
# exists: Rscript dev/make_references.R
# Output: tests/testthat/fixtures/v1_<function>.rds

# ==== Set up ============================== ----
## Paths                                   ----
path_to_fixtures <- file.path("tests", "testthat", "fixtures")
dir.create(path_to_fixtures, showWarnings = FALSE, recursive = TRUE)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

## Functions                               ----
extract_fixture <- function(name) {
    raster <- suppressMessages(read_climate(
        system.file("extdata", name, package = "c4e")))
    survey <- utils::read.csv(system.file("extdata", "survey.csv", package = "c4e"))
    points <- prepare_coord(survey, lat_var = lat, lon_var = lon) |>
        georef_coord(geom = c("lon", "lat"), crs = "EPSG:4326")
    tibble::as_tibble(extract_by_coord(raster, points))
}

# ==== Read ================================ ----
tmax_daily  <- extract_fixture("tmax_daily.tif")
pre_daily   <- extract_fixture("pre_daily.tif")
pre_monthly <- extract_fixture("pre_monthly.tif")

# ==== calc_par (v1 signature) ============= ----
v1_calc_par <- list(
    tmax_all = calc_par(tmax_daily, pars = list(avg = mean, sd = stats::sd)),
    pre_year = calc_par(pre_daily, pars = list(total = sum), agg_period = "year"),
    pre_month = calc_par(pre_daily,
                         pars = list(total = sum, wet = \(x) sum(x > 1)),
                         agg_period = "month"),
    pre_monthly_year = calc_par(pre_monthly, pars = list(avg = mean),
                                agg_period = "year")
)

# ==== Write =============================== ----
saveRDS(v1_calc_par, file.path(path_to_fixtures, "v1_calc_par.rds"))
