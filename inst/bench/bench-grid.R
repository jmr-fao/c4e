# Benchmark: grid indicators through the block engine (the table steps on
# blocks of cells) against terra's built-in tapp() for the one indicator it
# can compute, days above a threshold per year (plan §13). Run from the
# package root:
#   Rscript inst/bench/bench-grid.R
# Writes inst/bench/results-grid.md. Each case checks that both give the
# same counts before timing counts.

suppressMessages(pkgload::load_all(".", quiet = TRUE))
set.seed(1)

make_raster <- function(side, n_days) {
    dates <- as.Date("2021-01-01") + seq_len(n_days) - 1
    season <- 8 * sin(2 * pi * seq_len(n_days) / 365)
    values <- matrix(stats::rnorm(side * side * n_days, 28, 3), side * side) +
        rep(season, each = side * side)
    r <- terra::rast(nrows = side, ncols = side, xmin = 30, xmax = 30 + side * 0.05,
                     ymin = 0, ymax = side * 0.05, nlyrs = n_days, vals = values)
    terra::time(r) <- dates
    terra::units(r) <- "C"
    names(r) <- format(dates)
    set_raster_meta(r, list(variable = "tmax", time_step = "day"))
}

time_it <- function(expr) {
    gc(verbose = FALSE)
    start <- Sys.time()
    value <- force(expr)
    list(value = value, seconds = as.numeric(difftime(Sys.time(), start, units = "secs")))
}

cases <- list(c(side = 50, days = 1095), c(side = 100, days = 365))
rows <- list()
for (case in cases) {
    r <- make_raster(case[["side"]], case[["days"]])
    run <- function() suppressMessages(
        grid_indicators(r, above = 30, spells = FALSE,
                        control = extremes_control(verbose = FALSE)))
    old <- options(c4e.grid_fast = FALSE)
    engine <- time_it(run())
    options(old)
    fast <- time_it(run())
    builtin <- time_it(terra::tapp(r > 30, index = "years", fun = "sum"))
    with_spells <- time_it(suppressMessages(
        grid_indicators(r, above = c(30, 35), spells = TRUE,
                        control = extremes_control(verbose = FALSE))))
    days <- function(g) terra::values(g[[grep("^day_abv_30_sum", names(g))]])
    same <- isTRUE(all.equal(days(engine$value), terra::values(builtin$value),
                             check.attributes = FALSE)) &&
        isTRUE(all.equal(terra::values(fast$value), terra::values(engine$value)))
    rows[[length(rows) + 1]] <- sprintf(
        "| %d | %d | %.2f | %.2f | %.2f | %.1f | %.2f | %s |",
        case[["side"]]^2, case[["days"]], engine$seconds, fast$seconds,
        builtin$seconds, engine$seconds / fast$seconds, with_spells$seconds, same)
}

writeLines(c(
    "# Grid benchmark",
    "",
    paste0("Run on ", Sys.Date(), ", R ", getRversion(), ", ", Sys.info()[["sysname"]],
           ". Times in seconds, one run each, in memory."),
    "",
    "- **engine**: `grid_indicators(above = 30, spells = FALSE)` through the block",
    "  engine (`options(c4e.grid_fast = FALSE)`): the table steps on blocks of cells",
    "  (days above and their excess, per year).",
    "- **fast**: the same call on its default path, `terra::tapp()` sums.",
    "- **tapp**: `terra::tapp(r > 30, \"years\", \"sum\")`, days above only.",
    "- **with spells**: `grid_indicators(above = c(30, 35))` with spells, which",
    "  needs the engine.",
    "- **same**: the engine's day counts equal tapp's, and fast equals engine.",
    "",
    "| cells | days | engine (s) | fast (s) | tapp (s) | engine / fast | with spells (s) | same |",
    "|---|---|---|---|---|---|---|---|",
    unlist(rows)
), "inst/bench/results-grid.md")
