# Defaults from upstream metadata, messages, labels and history (plan §1, §9.6, §14)

# ==== c4e_default() ==========================================================

test_that("an explicit argument wins, silently", {
    expect_silent(out <- c4e_default(3L, from = 2L, arg_name = "min_spell"))
    expect_equal(out, 3L)
})

test_that("a value from upstream is used and announced", {
    expect_snapshot(out <- c4e_default(NULL, from = c(30, 35), arg_name = "above",
                                       field = "threshold"))
    expect_equal(out, c(30, 35))
    expect_message(c4e_default(NULL, from = "C", arg_name = "unit"),
                   class = "c4e_message")
})

test_that("the hard default is used silently when upstream has nothing", {
    expect_silent(out <- c4e_default(NULL, from = NULL, arg_name = "min_spell",
                                     default = 2L))
    expect_equal(out, 2L)
})

test_that("a required argument with nothing upstream is an error naming it", {
    expect_snapshot(error = TRUE,
                    c4e_default(NULL, from = NULL, arg_name = "unit"))
    expect_null(c4e_default(NULL, from = NULL, arg_name = "unit", required = FALSE))
})

test_that("messages can be silenced by option or by rlang verbosity", {
    withr::local_options(climatic4economist.verbose = FALSE)
    expect_silent(c4e_default(NULL, from = "C", arg_name = "unit"))

    withr::local_options(climatic4economist.verbose = TRUE,
                         rlib_message_verbosity = "quiet")
    expect_silent(c4e_default(NULL, from = "C", arg_name = "unit"))
})

# ==== check_meta_agrees() ====================================================

test_that("an explicit value that contradicts the metadata is an error", {
    expect_silent(check_meta_agrees("C", "C", "unit"))
    expect_silent(check_meta_agrees(NULL, "C", "unit"))
    expect_silent(check_meta_agrees(2L, 2, "min_spell"))
    expect_snapshot(error = TRUE,
                    check_meta_agrees("K", "C", "unit",
                                      hint = "Convert the data first."))
})

# ==== Labels and progress ====================================================

test_that("labels come from the argument, then the metadata", {
    meta <- modify_meta(empty_meta(), list(label = "Malawi19"))
    expect_equal(resolve_label("Mali22", meta = meta), "Mali22")
    expect_equal(resolve_label(NULL, meta = meta), "Malawi19")
    expect_null(resolve_label(NULL, meta = empty_meta()))
})

test_that("the old `iteration` argument still works but is deprecated", {
    # resolve_label() is called by a step function on the user's behalf
    step <- function(label = NULL, iteration = NULL) {
        resolve_label(label, iteration = iteration)
    }
    lifecycle::expect_deprecated(out <- step(iteration = "Mali22"))
    expect_equal(out, "Mali22")
})

test_that("values are written the way they would be typed", {
    expect_equal(format_value(c(30, 35)), "c(30, 35)")
    expect_equal(format_value("C"), "\"C\"")
    expect_equal(format_value(2L), "2L")
    expect_equal(format_value(as.Date("2024-09-01")), "as.Date(\"2024-09-01\")")
    expect_equal(format_value(list(interval = "1 year", n_lags = 2L)),
                 "list(interval = \"1 year\", n_lags = 2L)")
})

test_that("a progress step is shown only when verbose", {
    step <- function(label) {
        c4e_progress_step("Computing spells: {label}")
        invisible(TRUE)
    }
    withr::local_options(climatic4economist.verbose = FALSE)
    expect_silent(step("Mali22"))
    withr::local_options(climatic4economist.verbose = TRUE)
    expect_message(step("Mali22"), "Computing spells: Mali22")
})

# ==== History ================================================================

test_that("each step appends one entry with its resolved arguments", {
    started <- Sys.time() - 2
    meta <- c4e_record(empty_meta(), "calc_threshold_day",
                       args = list(above = c(30, 35), unit = "C", below = NULL),
                       started = started)
    meta <- c4e_record(meta, "calc_spell", args = list(min_spell = 2L))

    expect_length(meta$history, 2)
    first <- meta$history[[1]]
    expect_equal(first$fn, "calc_threshold_day")
    expect_equal(first$args, list(above = c(30, 35), unit = "C"))
    expect_gte(first$elapsed, 2)
    expect_s3_class(first$time, "POSIXct")
    expect_null(meta$history[[2]]$elapsed)
})

test_that("arguments that cannot be shown as code are left out", {
    meta <- c4e_record(empty_meta(), "extract_by_coord",
                       args = list(raster = terra::rast(), id = "ID",
                                   fn = mean, data = data.frame(a = 1)))
    expect_equal(meta$history[[1]]$args, list(id = "ID"))
})

test_that("c4e_history() prints the pipeline as code", {
    meta <- empty_meta()
    meta <- c4e_record(meta, "extract_by_coord", args = list(id = "ID"))
    meta <- c4e_record(meta, "calc_threshold_day", args = list(above = c(30, 35)))
    meta <- c4e_record(meta, "calc_spell", args = list(min_spell = 2L))
    # fixed timings so the snapshot is stable
    meta$history <- lapply(seq_along(meta$history), \(i) {
        entry <- meta$history[[i]]
        entry$elapsed <- c(0.8, 1.25, 62)[i]
        entry
    })
    x <- new_c4e_tbl(tibble::tibble(ID = "1"), meta)

    history <- c4e_history(x)
    expect_s3_class(history, "c4e_history")
    expect_equal(history$call, c(
        "extract_by_coord(id = \"ID\")",
        "calc_threshold_day(above = c(30, 35))",
        "calc_spell(min_spell = 2L)"
    ))
    expect_equal(history$elapsed, c(0.8, 1.25, 62))
    expect_snapshot(print(history))
})

test_that("c4e_history() of a table without history is empty", {
    expect_equal(nrow(c4e_history(tibble::tibble(ID = "1"))), 0L)
    expect_snapshot(print(c4e_history(tibble::tibble(ID = "1"))))
})

test_that("merging tables does not repeat shared history", {
    meta <- c4e_record(empty_meta(), "extract_by_coord", args = list(id = "ID"))
    a <- c4e_record(meta, "calc_threshold_day", args = list(above = 30))
    b <- c4e_record(meta, "calc_threshold_day", args = list(above = 35))

    merged <- merge_meta(a, b)
    fns <- vapply(merged$history, `[[`, "", "fn")
    expect_equal(fns, c("extract_by_coord", "calc_threshold_day",
                        "calc_threshold_day"))
})

# ==== resolve_key() reads the metadata first =================================

test_that("resolve_key() uses the key recorded in the metadata", {
    x <- new_c4e_tbl(tibble::tibble(site = "a", ID = "1", v = 1),
                     list(key = "site"))
    expect_equal(resolve_key(x), "site")
    # an explicit id still wins
    expect_equal(resolve_key(x, id = "ID"), "ID")
    # plain tables behave as before
    expect_equal(resolve_key(tibble::as_tibble(x)), "ID")
})
