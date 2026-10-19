# Memory budget and automatic splitting (plan §14)

# ==== Sizes and budget =======================================================

test_that("byte sizes parse from numbers and strings", {
    expect_equal(parse_bytes(1e6), 1e6)
    expect_equal(parse_bytes("8GB"), 8 * 1024^3)
    expect_equal(parse_bytes("512 MB"), 512 * 1024^2)
    expect_equal(parse_bytes("1.5gib"), 1.5 * 1024^3)
    expect_equal(parse_bytes("2048"), 2048)
    expect_error(parse_bytes("lots"), "number of bytes")
    expect_error(parse_bytes(-1), "number of bytes")
})

test_that("byte sizes print in readable units", {
    expect_equal(format_bytes(512), "512 B")
    expect_equal(format_bytes(1536), "1.5 KB")
    expect_equal(format_bytes(12.43 * 1024^3), "12.4 GB")
})

test_that("the memory budget follows the option, else half the free memory", {
    withr::local_options(climatic4economist.mem_limit = "2GB")
    expect_equal(mem_budget(), 2 * 1024^3)

    withr::local_options(climatic4economist.mem_limit = NULL)
    budget <- mem_budget()
    expect_gt(budget, 0)
    expect_lt(budget, terra::free_RAM() * 1024)
})

test_that("sizes are estimated from rows, columns and type", {
    expect_equal(estimate_bytes(1000, 10), 80000)
    expect_equal(estimate_bytes(1000, 10, type = "integer"), 40000)
    expect_error(estimate_bytes(10, 1, type = "complex"))
})

# ==== with_chunks() ==========================================================

# twelve units with five rows each; the per-unit mean is the toy computation
toy_tbl <- function() {
    x <- tibble::tibble(
        ID    = rep(sprintf("%02d", 1:12), each = 5),
        value = seq_len(60) / 2
    )
    new_c4e_tbl(x, list(key = "ID", variable = "tmax", unit = "C"))
}
mean_by_id <- function(x) {
    out <- dplyr::summarise(tibble::as_tibble(x), mean = mean(value), .by = ID)
    new_c4e_tbl(out, list(key = "ID", unit = c4e_meta(x, "unit")))
}

test_that("nothing is split while the estimate fits the budget", {
    calls <- 0
    fn <- function(x) {
        calls <<- calls + 1
        mean_by_id(x)
    }
    withr::local_options(climatic4economist.mem_limit = "1GB")
    expect_silent(out <- with_chunks(toy_tbl(), fn, mem_estimate = 1e6))
    expect_equal(calls, 1)
    expect_equal(out, mean_by_id(toy_tbl()))

    # no estimate means nothing to split on
    expect_silent(with_chunks(toy_tbl(), fn))
})

test_that("an estimate over the budget splits by unit and gives the same result", {
    withr::local_options(climatic4economist.mem_limit = "1KB")
    calls <- 0
    fn <- function(x) {
        calls <<- calls + 1
        mean_by_id(x)
    }
    expect_snapshot(
        out <- with_chunks(toy_tbl(), fn, mem_estimate = 3.5 * 1024,
                           label = "Window summaries", what = "locations")
    )
    expect_equal(calls, 4)
    expect_equal(out, mean_by_id(toy_tbl()))
    expect_true(is_c4e_tbl(out))
    expect_equal(c4e_meta(out, "unit"), "C")
})

test_that("a unit is never split across chunks", {
    withr::local_options(climatic4economist.mem_limit = "1KB")
    seen <- list()
    fn <- function(x) {
        seen[[length(seen) + 1]] <<- unique(x$ID)
        x
    }
    suppressMessages(with_chunks(toy_tbl(), fn, mem_estimate = 5 * 1024))
    ids <- unlist(seen)
    expect_equal(length(ids), 12)
    expect_false(anyDuplicated(ids) > 0)
})

test_that("chunk = <n> forces n units per chunk, chunk = FALSE forbids splitting", {
    calls <- 0
    fn <- function(x) {
        calls <<- calls + 1
        mean_by_id(x)
    }
    expect_snapshot(out <- with_chunks(toy_tbl(), fn, chunk = 5, what = "locations"))
    expect_equal(calls, 3)
    expect_equal(out, mean_by_id(toy_tbl()))

    withr::local_options(climatic4economist.mem_limit = "1KB")
    expect_snapshot(error = TRUE,
                    with_chunks(toy_tbl(), fn, chunk = FALSE, mem_estimate = 4096,
                                label = "Window summaries"))
    expect_error(with_chunks(toy_tbl(), fn, chunk = 0), "chunk")
    expect_error(with_chunks(toy_tbl(), fn, chunk = "yes"), "chunk")
})

test_that("several tables are split on the same units", {
    survey <- tibble::tibble(ID = rep(sprintf("%02d", 1:12), 2),
                             hhid = sprintf("HH%02d", 1:24))
    fn <- function(parts) {
        expect_setequal(unique(parts$survey$ID), unique(parts$values$ID))
        dplyr::left_join(parts$survey, mean_by_id(parts$values), by = "ID")
    }
    out <- with_chunks(list(survey = survey, values = toy_tbl()), fn,
                       by = "ID", chunk = 4, label = "Joining")
    expect_equal(nrow(out), 24)
    expect_equal(dplyr::arrange(out, hhid),
                 dplyr::arrange(fn(list(survey = survey, values = toy_tbl())), hhid))
})

test_that("splitting runs through furrr when asked", {
    out <- suppressMessages(
        with_chunks(toy_tbl(), mean_by_id, chunk = 3, .parallel = TRUE))
    expect_equal(out, mean_by_id(toy_tbl()))
})

test_that("splitting is silent when messages are off", {
    withr::local_options(climatic4economist.verbose = FALSE)
    expect_silent(with_chunks(toy_tbl(), mean_by_id, chunk = 2))
})

test_that("splitting the extracted fixture table gives the unsplit result", {
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    points <- georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
    tmax <- extract_by_coord(synthetic_daily("tmax")[[1:60]], points)

    summarise_units <- function(x) {
        x |>
            tidyr::pivot_longer(dplyr::matches(date_pattern()), names_to = "date") |>
            dplyr::summarise(hot = sum(value > 300), .by = ID) |>
            dplyr::arrange(ID)
    }
    estimate <- estimate_bytes(nrow(tmax), 60)
    withr::local_options(climatic4economist.mem_limit = estimate / 3)

    out <- suppressMessages(with_chunks(tmax, summarise_units,
                                        mem_estimate = estimate))
    expect_equal(dplyr::arrange(out, ID), summarise_units(tmax))
})
