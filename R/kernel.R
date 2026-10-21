# The matrix kernel (plan §10.1, §13).
#
# A wide table is a matrix of units by dates in disguise. These internal
# functions compute on that matrix: one row per unit (or raster cell), one
# column per date, in calendar order. Each takes and returns matrices of the
# same shape, so the same code serves tables (rows are units) and rasters
# (rows are cells, read block by block). Long tables are built once, at the
# end, by matrix_to_long().
#
# Every result equals what the v1 long-format functions give
# (tests/testthat/test-kernel.R); the rules are the v1 rules:
# * flags: value > threshold (above) or value < threshold (below); NA stays NA;
# * excess: the distance beyond the threshold, 0 when not beyond, NA stays NA;
# * spells: runs of TRUE, broken by FALSE or NA; the run length is written on
#   the run's last day when it reaches `min_spell`, NA elsewhere;
# * percentiles: R's default (type 7) quantile, per unit and calendar month.

# ==== Wide table <-> matrix =============================================== ----

#' Units-by-dates matrix of a wide table
#'
#' Rows are the distinct units, identified by the key and the identifying
#' columns recorded in the metadata (`unit_cols`), sorted by key as v1 did
#' (C locale). Columns are the date columns in calendar order.
#'
#' @return A list with `values` (numeric matrix), `ids` (tibble of the
#'   identifying columns, one row per unit) and `dates` (Date, one per column).
#' @noRd
as_matrix_wide <- function(x, id = NULL, call = rlang::caller_env()) {
    meta <- c4e_meta(x) %||% empty_meta()
    key <- resolve_key(x, id)
    id_cols <- unique(c(key, intersect(meta$unit_cols, names(x))))
    date_cols <- grep(date_pattern(), names(x), value = TRUE)
    if (length(date_cols) == 0) {
        cli::cli_abort("{.arg x} has no date columns.", call = call)
    }
    dates <- parse_date_label(to_date(date_cols))
    if (anyNA(dates)) {
        bad <- date_cols[is.na(dates)]
        cli::cli_abort("Column{?s} {.field {bad}} {?does/do} not read as dates.",
                       call = call)
    }

    data <- tibble::as_tibble(x)
    data <- data[!duplicated(data[id_cols]), , drop = FALSE]
    data <- data[do.call(order, c(unname(as.list(data[id_cols])), method = "radix")), ,
                 drop = FALSE]
    by_date <- order(dates)

    values <- as.matrix(data[date_cols[by_date]])
    storage.mode(values) <- "double"
    keys <- as.character(data[[key]])
    dimnames(values) <- list(if (!anyDuplicated(keys)) keys,
                             format(dates[by_date]))
    list(values = values, ids = data[id_cols], dates = dates[by_date])
}

#' Long table from a units-by-dates matrix, ordered by unit then date
#'
#' @param values Matrix of the base series, or ignored when `value_name` is
#'   `NULL`.
#' @param ids Tibble of identifying columns, one row per matrix row.
#' @param dates One date per matrix column.
#' @param value_name Name of the column for `values`; `NULL` to leave it out.
#' @param extra Named list of further matrices of the same shape, one column
#'   each in the result.
#' @noRd
matrix_to_long <- function(values, ids, dates, value_name = "value",
                           extra = list()) {
    n_units <- nrow(ids)
    n_dates <- length(dates)
    out <- ids[rep(seq_len(n_units), each = n_dates), , drop = FALSE]
    out$date <- rep(dates, times = n_units)
    if (!is.null(value_name)) {
        out[[value_name]] <- as.vector(t(values))
    }
    for (name in names(extra)) {
        out[[name]] <- as.vector(t(extra[[name]]))
    }
    tibble::as_tibble(out)
}

#' Long c4e table from a wide one: key, identifying columns, date, value
#'
#' The context is kept; the result records `shape = "long"` and
#' `date_col = "date"`.
#' @noRd
to_long <- function(x, id = NULL) {
    m <- as_matrix_wide(x, id)
    out <- matrix_to_long(m$values, m$ids, m$dates)
    meta <- modify_meta(c4e_meta(x) %||% empty_meta(), list(
        key        = resolve_key(x, id),
        shape      = "long",
        date_col   = "date",
        date_range = range(m$dates)
    ))
    new_c4e_tbl(out, prune_meta(meta, names(out)))
}

# ==== Thresholds ========================================================== ----

#' Is each value beyond the threshold?
#'
#' @param values Numeric matrix.
#' @param threshold A number, or a matrix of the same shape (one threshold
#'   per value, e.g. from `lookup_by_month()`).
#' @param direction `"above"` or `"below"`.
#' @noRd
flag_threshold <- function(values, threshold, direction = c("above", "below")) {
    direction <- match.arg(direction)
    if (direction == "above") values > threshold else values < threshold
}

#' How far beyond the threshold each value is; 0 when not beyond
#' @noRd
excess_threshold <- function(values, threshold, direction = c("above", "below")) {
    direction <- match.arg(direction)
    excess <- if (direction == "above") values - threshold else threshold - values
    excess[!is.na(excess) & excess < 0] <- 0
    excess
}

# ==== Spells ============================================================== ----

#' Spell lengths, row by row
#'
#' Counts runs of `TRUE` along each row; `FALSE` and `NA` end a run, and a
#' run never continues into the next row. The run length is written on the
#' run's last day when it is at least `min_spell`; every other cell is `NA`.
#' Equals `compute_spell()` applied to each row, without a loop.
#'
#' @param flags Logical matrix, one row per unit, dates in order.
#' @noRd
run_length_rows <- function(flags, min_spell = 2) {
    n_row <- nrow(flags)
    n_col <- ncol(flags)
    n <- n_row * n_col
    out <- rep(NA_integer_, n)
    if (n == 0) {
        return(matrix(out, n_row, n_col, dimnames = dimnames(flags)))
    }

    run <- as.vector(t(flags))          # each row's days are contiguous
    run[is.na(run)] <- FALSE
    starts_run <- c(TRUE, run[-1] != run[-n])
    starts_run[seq.int(1, n, by = n_col)] <- TRUE
    first_day <- which(starts_run)
    last_day  <- c(first_day[-1] - 1L, n)
    lengths   <- last_day - first_day + 1L

    keep <- run[last_day] & lengths >= min_spell
    out[last_day[keep]] <- as.integer(lengths[keep])
    matrix(out, n_row, n_col, byrow = TRUE, dimnames = dimnames(flags))
}

# ==== Percentiles ========================================================= ----

#' Quantiles of each row, as stats::quantile(type = 7, na.rm = TRUE) gives
#'
#' Rows with no value get `replace`. The interpolation reproduces R's code,
#' so results are identical, not just close.
#' @noRd
row_quantiles <- function(values, p, replace = NA_real_) {
    n_row <- nrow(values)
    out <- matrix(as.numeric(replace), n_row, length(p))
    if (n_row == 0 || ncol(values) == 0) {
        return(out)
    }
    sorted <- if (ncol(values) == 1) {
        values
    } else {
        t(apply(values, 1, sort, na.last = TRUE))
    }
    if (n_row == 1 && ncol(values) > 1) {
        sorted <- matrix(sorted, nrow = 1)
    }
    n <- rowSums(!is.na(values))
    rows <- which(n > 0)

    for (j in seq_along(p)) {
        index <- 1 + (n[rows] - 1) * p[j]
        lo <- floor(index)
        hi <- ceiling(index)
        qs <- sorted[cbind(rows, lo)]
        above <- sorted[cbind(rows, hi)]
        i <- which(index > lo & above != qs)
        h <- (index - lo)[i]
        qs[i] <- (1 - h) * qs[i] + h * above[i]
        out[rows, j] <- qs
    }
    out
}

#' Percentiles per unit and calendar month, over all years
#'
#' @param values Numeric matrix, units by dates.
#' @param dates One date per column.
#' @param p Probabilities, e.g. `c(0.1, 0.9)`.
#' @param exclude_below,exclude_above Values beyond these are left out, e.g.
#'   `exclude_below = 0.1` for wet-day percentiles of precipitation.
#' @param replace Value for a unit and month with no data left.
#' @return A named list, one matrix per probability (names like `"90p"`),
#'   units by months (`"01"` to `"12"`, the months present in `dates`).
#' @noRd
quantile_by_month <- function(values, dates, p, exclude_below = NULL,
                              exclude_above = NULL, replace = NA_real_) {
    if (!is.null(exclude_below)) {
        values[!is.na(values) & values < exclude_below] <- NA
    }
    if (!is.null(exclude_above)) {
        values[!is.na(values) & values > exclude_above] <- NA
    }
    months <- month_label(dates)
    labels <- sort(unique(months))

    out <- lapply(p, \(probability) {
        matrix(NA_real_, nrow(values), length(labels),
               dimnames = list(rownames(values), labels))
    })
    for (k in seq_along(labels)) {
        quantiles <- row_quantiles(values[, months == labels[k], drop = FALSE],
                                   p, replace)
        for (j in seq_along(p)) {
            out[[j]][, k] <- quantiles[, j]
        }
    }
    names(out) <- paste0(p * 100, "p")
    out
}

#' A threshold per value: each date gets its unit's value for that month
#'
#' @param table Matrix of units by months (columns `"01"` to `"12"`), e.g.
#'   one element of `quantile_by_month()`.
#' @param dates One date per column of the values to compare with.
#' @noRd
lookup_by_month <- function(table, dates) {
    out <- table[, match(month_label(dates), colnames(table)), drop = FALSE]
    colnames(out) <- format(dates)
    out
}

# ==== Standardised indices ================================================ ----

#' SPI or SPEI for each row of a units-by-months matrix
#'
#' Fits each series on its own: probed on SPEI 1.8.1, one call on a whole
#' matrix gives the same numbers but takes over twice as long.
#'
#' @param values Monthly precipitation (SPI) or water balance (SPEI), units
#'   by months in order.
#' @param scale Accumulation period in months.
#' @param index `"spi"` or `"spei"`.
#' @param .parallel When `TRUE`, fit the series with `furrr::future_map()`.
#' @noRd
spi_matrix <- function(values, scale, index = c("spi", "spei"),
                       .parallel = FALSE) {
    index <- match.arg(index)
    fit <- switch(index, spi = SPEI::spi, spei = SPEI::spei)
    one <- function(i) {
        as.numeric(stats::fitted(fit(values[i, ], scale = scale,
                                     verbose = FALSE, na.rm = TRUE)))
    }
    rows <- seq_len(nrow(values))
    if (.parallel) {
        rlang::check_installed("furrr", reason = "to fit the series in parallel.")
    }
    fitted_rows <- if (.parallel) {
        furrr::future_map(rows, one, .options = furrr::furrr_options(seed = TRUE))
    } else {
        lapply(rows, one)
    }
    out <- matrix(unlist(fitted_rows), nrow(values), ncol(values), byrow = TRUE)
    dimnames(out) <- dimnames(values)
    out
}

# ==== Rasters ============================================================= ----

#' Apply a kernel to a raster, block of rows by block of rows
#'
#' Reads the raster in blocks as matrices of cells by layers, applies `fun`,
#' and writes the result, so stacks larger than memory can be processed.
#' terra::app() cannot do this: it calls its function once per cell (probed
#' on terra 1.9.46).
#'
#' @param x A `SpatRaster`.
#' @param fun A function from a cells-by-layers matrix to a cells-by-k
#'   matrix, the same k for every block.
#' @param names Layer names of the result; by default those of `x` when the
#'   number of layers is kept.
#' @param rows_per_block Raster rows per block; by default terra's choice.
#' @param filename Optional file to write to.
#' @param ... Passed to `terra::writeStart()`, e.g. `wopt`.
#' @noRd
apply_kernel_raster <- function(x, fun, names = NULL, rows_per_block = NULL,
                                filename = "", ...) {
    if (is.null(rows_per_block)) {
        blocks <- terra::blocks(x)
        starts <- blocks$row
        n_rows <- blocks$nrows
    } else {
        starts <- seq.int(1, terra::nrow(x), by = rows_per_block)
        n_rows <- pmin(rows_per_block, terra::nrow(x) - starts + 1)
    }

    terra::readStart(x)
    on.exit(terra::readStop(x), add = TRUE)
    compute <- function(i) {
        result <- fun(terra::readValues(x, row = starts[i], nrows = n_rows[i],
                                        mat = TRUE))
        result <- as.matrix(result)
        storage.mode(result) <- "double"
        result
    }

    first <- compute(1)
    n_out <- ncol(first)
    layer_names <- names %||%
        (if (n_out == terra::nlyr(x)) base::names(x) else paste0("lyr", seq_len(n_out)))
    out <- terra::rast(x, nlyrs = n_out)
    terra::writeStart(out, filename = filename, overwrite = TRUE, ...)
    terra::writeValues(out, first, starts[1], n_rows[1])
    for (i in seq_along(starts)[-1]) {
        terra::writeValues(out, compute(i), starts[i], n_rows[i])
    }
    out <- terra::writeStop(out)

    base::names(out) <- layer_names
    if (n_out == terra::nlyr(x) && terra::has.time(x)) {
        terra::time(out) <- terra::time(x)
    }
    out
}
