# Benchmark: v1 long-format indicator functions against the matrix kernel
# (plan §10.1, §10.7). Run from the package root:
#   Rscript inst/bench/bench-kernel.R
# Writes inst/bench/results.md. Each case checks that both give the same
# result before timing counts.

suppressMessages(pkgload::load_all(".", quiet = TRUE))
set.seed(1)

# ==== Data ================================================================= ----
make_wide <- function(n_units, n_days) {
    dates <- format(as.Date("2021-01-01") + seq_len(n_days) - 1)
    season <- 8 * sin(2 * pi * seq_len(n_days) / 365)
    values <- matrix(stats::rnorm(n_units * n_days, 28, 3), n_units) +
        rep(season, each = n_units)
    colnames(values) <- dates
    tibble::as_tibble(values) |>
        tibble::add_column(ID = sprintf("%05d", seq_len(n_units)), .before = 1)
}

time_it <- function(expr) {
    gc(verbose = FALSE)
    start <- Sys.time()
    value <- force(expr)
    list(value = value, seconds = as.numeric(difftime(Sys.time(), start, units = "secs")))
}

# ==== Cases ================================================================ ----
# absolute thresholds with excess, then spells
v1_absolute <- function(wide) {
    find_extr_abs_day(wide, u_thresh = c(30, 35), unit = "C") |>
        find_spell(min_spell = 2) |>
        tibble::as_tibble() |>
        dplyr::select(ID, date, spell_abv_30, spell_abv_35) |>
        dplyr::arrange(ID, date)
}
kernel_absolute <- function(wide) {
    m <- as_matrix_wide(wide)
    flags_30 <- flag_threshold(m$values, 30, "above")
    flags_35 <- flag_threshold(m$values, 35, "above")
    excess_30 <- excess_threshold(m$values, 30, "above")
    excess_35 <- excess_threshold(m$values, 35, "above")
    matrix_to_long(m$values, m$ids["ID"], m$dates, value_name = NULL,
                   extra = list(spell_abv_30 = run_length_rows(flags_30, 2),
                                spell_abv_35 = run_length_rows(flags_35, 2)))
}

# monthly percentiles
v1_percentile <- function(wide) {
    tibble::as_tibble(calc_pct_day(wide, p = c(0.9, 0.95))) |>
        dplyr::arrange(ID, month)
}
kernel_percentile <- function(wide) {
    m <- as_matrix_wide(wide)
    pct <- quantile_by_month(m$values, m$dates, p = c(0.9, 0.95))
    tibble::tibble(
        ID      = rep(m$ids$ID, each = ncol(pct[[1]])),
        month   = rep(colnames(pct[[1]]), times = nrow(m$ids)),
        day_90p = as.vector(t(pct[["90p"]])),
        day_95p = as.vector(t(pct[["95p"]]))
    )
}

# ==== Run ================================================================== ----
sizes <- list(c(units = 1000, days = 1095), c(units = 10000, days = 365))
rows <- list()
for (size in sizes) {
    wide <- make_wide(size[["units"]], size[["days"]])
    for (case in c("absolute", "percentile")) {
        v1 <- time_it(get(paste0("v1_", case))(wide))
        kernel <- time_it(get(paste0("kernel_", case))(wide))
        same <- isTRUE(all.equal(v1$value, kernel$value, check.attributes = FALSE))
        rows[[length(rows) + 1]] <- data.frame(
            case = case, units = size[["units"]], days = size[["days"]],
            v1_s = round(v1$seconds, 2), kernel_s = round(kernel$seconds, 2),
            speedup = round(v1$seconds / kernel$seconds, 1), same_result = same
        )
        cat(case, size[["units"]], "x", size[["days"]], ":", round(v1$seconds, 2),
            "s vs", round(kernel$seconds, 2), "s, same:", same, "\n")
    }
}
results <- do.call(rbind, rows)

# ==== Write ================================================================ ----
header <- c(
    "# Kernel benchmark",
    "",
    paste0("Run on ", format(Sys.Date()), ", R ", getRversion(), ", ",
           Sys.info()[["sysname"]], ". Times in seconds, one run each, ",
           "including building the long result."),
    "",
    "- **absolute**: flags and excess above 30 and 35, then spells of at least 2 days",
    "  (`find_extr_abs_day()` + `find_spell()` against the kernel).",
    "- **percentile**: monthly 90th and 95th percentiles (`calc_pct_day()` against",
    "  `quantile_by_month()`).",
    "",
    "| case | units | days | v1 (s) | kernel (s) | speed-up | same result |",
    "|---|---|---|---|---|---|---|"
)
table <- apply(results, 1, \(r) paste0("| ", paste(trimws(r), collapse = " | "), " |"))
writeLines(c(header, table), file.path("inst", "bench", "results.md"))
