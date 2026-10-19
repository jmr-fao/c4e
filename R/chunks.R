# Memory budget and automatic splitting of heavy computations (plan §14).
#
# A heavy step estimates the size of its largest intermediate before building
# it. When the estimate exceeds the memory budget, with_chunks() splits the
# work by unit (location, cell, division), runs it piece by piece with a
# progress bar, and binds the pieces back together. Units are never split
# across pieces, so the result equals the unsplit computation.

# ==== Sizes and budget ==================================================== ----

#' Bytes from a number or a string such as "8GB" or "512 MB"
#'
#' Units are binary: 1 KB = 1024 bytes, matching how memory is reported.
#' @noRd
parse_bytes <- function(x, arg = "mem_limit", call = rlang::caller_env()) {
    if (is.numeric(x) && length(x) == 1 && isTRUE(x > 0)) {
        return(as.numeric(x))
    }
    if (rlang::is_string(x)) {
        parts <- regmatches(
            toupper(x),
            regexec("^\\s*([0-9]*\\.?[0-9]+)\\s*([KMGT]?)I?B?\\s*$", toupper(x))
        )[[1]]
        if (length(parts) == 3) {
            power <- match(parts[3], c("", "K", "M", "G", "T")) - 1
            return(as.numeric(parts[2]) * 1024^power)
        }
    }
    cli::cli_abort(
        "{.arg {arg}} must be a positive number of bytes or a string such as
         {.val 8GB}.",
        call = call)
}

#' Readable size, e.g. "12.4 GB"
#' @noRd
format_bytes <- function(bytes) {
    power <- min(max(floor(log(max(bytes, 1), 1024)), 0), 4)
    value <- bytes / 1024^power
    digits <- if (power == 0) 0 else 1
    paste(format(round(value, digits), nsmall = digits, trim = TRUE),
          c("B", "KB", "MB", "GB", "TB")[power + 1])
}

#' How much memory a heavy step may use
#'
#' `options(climatic4economist.mem_limit = "8GB")` sets the budget; otherwise
#' it is half of the free memory reported by [terra::free_RAM()], which
#' counts kilobytes.
#' @noRd
mem_budget <- function() {
    limit <- getOption("climatic4economist.mem_limit")
    if (!is.null(limit)) {
        return(parse_bytes(limit, arg = "options(climatic4economist.mem_limit)"))
    }
    free_kb <- tryCatch(terra::free_RAM(), error = function(e) NA_real_)
    if (!isTRUE(free_kb > 0)) {
        return(4 * 1024^3)
    }
    0.5 * free_kb * 1024
}

#' Size of a table of `n_rows` by `n_cols` values of one type
#' @noRd
estimate_bytes <- function(n_rows, n_cols = 1, type = "double") {
    size <- c(double = 8, integer = 4, logical = 4, character = 8)
    type <- rlang::arg_match(type, names(size))
    as.numeric(n_rows) * as.numeric(n_cols) * size[[type]]
}

# ==== Splitting =========================================================== ----

#' Run a computation on a table, split by unit when it would not fit in memory
#'
#' @param x A data frame, or a named list of data frames that share the `by`
#'   columns (for example a survey and its indicators). A list is split on the
#'   same units in every table, and `fn` receives a list of the same shape.
#' @param fn The computation: takes a piece shaped like `x` and returns a data
#'   frame (or anything, when not split).
#' @param by Columns identifying the units. Default: the key recorded in the
#'   metadata, else the usual key columns.
#' @param chunk `"auto"` splits only when `mem_estimate` exceeds the budget,
#'   into as many pieces as needed; a positive integer forces that many units
#'   per piece; `FALSE` never splits and errors when over budget.
#' @param mem_estimate Estimated bytes of the largest intermediate when run on
#'   all of `x`, e.g. from `estimate_bytes()`.
#' @param label Name of the computation, for messages and the progress bar.
#' @param what Name of the units, for messages, e.g. `"locations"`.
#' @param detail Optional text explaining the estimate, e.g. `"1,234
#'   households x 15,706 days"`.
#' @param .parallel When `TRUE`, run the pieces with [furrr::future_map()],
#'   following the user's `future::plan()`.
#' @return The result of `fn`, with the pieces bound by `vctrs::vec_rbind()`
#'   so the metadata of `c4e_tbl` pieces is merged.
#' @noRd
with_chunks <- function(x, fn, by = NULL, chunk = "auto", mem_estimate = NULL,
                        label = "Computing", what = "units", detail = NULL,
                        .parallel = FALSE, call = rlang::caller_env()) {
    single <- is.data.frame(x)
    tables <- if (single) list(x) else x
    if (!is.list(tables) || length(tables) == 0 ||
        !all(vapply(tables, is.data.frame, logical(1)))) {
        cli::cli_abort("{.arg x} must be a data frame or a list of data frames.",
                       call = call)
    }
    check_chunk(chunk, call)

    by <- by %||% c4e_meta(tables[[1]], "key") %||% resolve_key(tables[[1]])
    for (name in names(tables) %||% seq_along(tables)) {
        absent <- setdiff(by, names(tables[[name]]))
        if (length(absent) > 0) {
            cli::cli_abort("Column{?s} {.field {absent}} {?is/are} missing from
                            {.arg x}.", call = call)
        }
    }

    budget <- mem_budget()
    over_budget <- !is.null(mem_estimate) && mem_estimate > budget
    size_text <- if (!is.null(mem_estimate)) {
        paste0(format_bytes(mem_estimate), if (!is.null(detail)) paste0(" (", detail, ")"))
    }

    if (isFALSE(chunk)) {
        if (over_budget) {
            budget_text <- format_bytes(budget)
            cli::cli_abort(
                c("{label} needs about {size_text}, more than the memory budget
                   of {budget_text}.",
                  "i" = "Allow splitting with {.code chunk = \"auto\"}, or raise
                         the budget with
                         {.code options(climatic4economist.mem_limit = ...)}."),
                call = call)
        }
        return(fn(x))
    }

    # units across all tables, in order of first appearance
    key_of <- function(table) tibble::as_tibble(table)[by]
    keys   <- vctrs::vec_unique(vctrs::vec_rbind(!!!lapply(unname(tables), key_of)))
    n_keys <- vctrs::vec_size(keys)

    if (identical(chunk, "auto")) {
        if (!over_budget) {
            return(fn(x))
        }
        n_chunks  <- min(ceiling(mem_estimate / budget), n_keys)
        per_chunk <- ceiling(n_keys / n_chunks)
    } else {
        per_chunk <- as.integer(chunk)
    }
    n_chunks <- ceiling(n_keys / per_chunk)
    if (n_chunks <= 1) {
        if (over_budget) {
            cli::cli_warn("{label} needs about {size_text}, but a single {what}
                           cannot be split further.", call = call)
        }
        return(fn(x))
    }

    # tell the user why and how the work is split
    if (identical(chunk, "auto")) {
        budget_text <- format_bytes(budget)
        c4e_inform(c(
            "i" = "{label} needs about {size_text}; the memory budget is
                   {budget_text}.",
            " " = "Splitting {n_keys} {what} into {n_chunks} chunks."
        ))
    } else {
        c4e_inform(c(
            "i" = "{label}: splitting {n_keys} {what} into {n_chunks} chunks of
                   up to {per_chunk}."
        ))
    }

    key_chunk <- ceiling(seq_len(n_keys) / per_chunk)
    pieces <- lapply(seq_len(n_chunks), \(k) {
        piece <- lapply(tables, \(table) {
            rows <- which(key_chunk[vctrs::vec_match(key_of(table), keys)] == k)
            vctrs::vec_slice(table, rows)
        })
        if (single) piece[[1]] else piece
    })

    results <- if (.parallel) {
        furrr::future_map(pieces, fn, .options = furrr::furrr_options(seed = TRUE))
    } else {
        run_pieces(pieces, fn, label)
    }
    combine_pieces(results)
}

check_chunk <- function(chunk, call) {
    ok <- identical(chunk, "auto") || isFALSE(chunk) ||
        (is.numeric(chunk) && length(chunk) == 1 && isTRUE(chunk >= 1) &&
             chunk == round(chunk))
    if (!ok) {
        cli::cli_abort(
            "{.arg chunk} must be {.val auto}, {.code FALSE}, or a whole number of
             units per chunk.",
            call = call)
    }
}

#' Run the pieces one after the other, with a progress bar
#' @noRd
run_pieces <- function(pieces, fn, label) {
    n <- length(pieces)
    bar <- NULL
    if (c4e_verbose()) {
        bar <- cli::cli_progress_bar(
            name   = label,
            total  = n,
            format = "{cli::pb_name}{cli::pb_bar} chunk {cli::pb_current}/{cli::pb_total} | {cli::pb_elapsed} | ETA {cli::pb_eta}"
        )
    }
    results <- vector("list", n)
    for (k in seq_len(n)) {
        results[[k]] <- fn(pieces[[k]])
        if (!is.null(bar)) cli::cli_progress_update(id = bar)
    }
    if (!is.null(bar)) cli::cli_progress_done(id = bar)
    results
}

#' Bind the pieces' results; c4e_tbl metadata is merged by vctrs
#' @noRd
combine_pieces <- function(results) {
    if (all(vapply(results, is.data.frame, logical(1)))) {
        return(vctrs::vec_rbind(!!!results))
    }
    results
}
