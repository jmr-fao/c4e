# Shared by the calc_*() indicator functions (plan §1, §3, §11, §14).
#
# Indicator functions accept a wide table (straight from extract_*()) or a
# long one (from an earlier indicator step), and always return a long
# c4e_tbl: the earlier columns plus the new indicator columns, each described
# in the registry. The computation runs on units-by-dates matrices (the
# kernel); an "indicator frame" maps those matrices onto the rows of the long
# table, whatever their order.

# ==== Indicator frame ===================================================== ----

#' Long table with its units-by-dates grid
#'
#' @return A list: `data` (long c4e_tbl), `meta`, `key`, `id_cols`,
#'   `date_col`, `ids` (one row per unit, sorted), `dates` (sorted, unique)
#'   and `rows` (matrix units by dates of row numbers in `data`, `NA` where
#'   the table has no row).
#' @noRd
indicator_frame <- function(x, id = NULL, call = rlang::caller_env()) {
    meta <- c4e_meta(x) %||% empty_meta()
    date_col <- meta$date_col %||% (if ("date" %in% names(x)) "date")
    wide <- identical(meta$shape, "wide") ||
        (is.null(date_col) && any(grepl(date_pattern(), names(x))))

    if (wide) {
        long <- to_long(x, id)
        date_col <- "date"
    } else {
        if (is.null(date_col)) {
            cli::cli_abort(
                "{.arg x} has neither date columns nor a {.field date} column.",
                call = call)
        }
        long <- new_c4e_tbl(x, modify_meta(meta, list(
            key = resolve_key(x, id), shape = "long", date_col = date_col)))
    }
    meta <- c4e_meta(long)
    key <- meta$key
    id_cols <- unique(c(key, intersect(meta$unit_cols, names(long))))

    data <- tibble::as_tibble(long)
    dates_by_row <- parse_date_label(data[[date_col]])
    ids <- vctrs::vec_unique(data[id_cols])
    ids <- ids[do.call(order, c(unname(as.list(ids)), method = "radix")), , drop = FALSE]
    dates <- sort(unique(dates_by_row[!is.na(dates_by_row)]))

    unit_index <- vctrs::vec_match(data[id_cols], ids)
    date_index <- match(dates_by_row, dates)
    if (anyDuplicated(cbind(unit_index, date_index)) > 0) {
        cli::cli_abort("{.arg x} has more than one row for some unit and date.",
                       call = call)
    }
    rows <- matrix(NA_integer_, nrow(ids), length(dates))
    ok <- !is.na(date_index)
    rows[cbind(unit_index[ok], date_index[ok])] <- which(ok)

    list(data = long, meta = meta, key = key, id_cols = id_cols,
         date_col = date_col, ids = ids, dates = dates, rows = rows)
}

#' One column of the long table as a units-by-dates matrix
#' @noRd
frame_matrix <- function(frame, col) {
    matrix(tibble::as_tibble(frame$data)[[col]][frame$rows],
           nrow(frame$rows), ncol(frame$rows))
}

#' Put units-by-dates matrices back as columns of the long table
#' @noRd
frame_columns <- function(frame, columns) {
    data <- tibble::as_tibble(frame$data)
    present <- !is.na(frame$rows)
    for (name in names(columns)) {
        m <- columns[[name]]
        values <- rep(m[NA_integer_], nrow(data))
        values[frame$rows[present]] <- m[present]
        data[[name]] <- values
    }
    data
}

#' Rows in canonical order: unit, then date (or month)
#' @noRd
sort_long <- function(data, order_cols) {
    data[do.call(order, c(unname(as.list(data[order_cols])), method = "radix")), ,
         drop = FALSE]
}

# ==== Names =============================================================== ----

#' Prefix of flag columns, after the time step: day_, hr_, mo_, yr_
#' @noRd
step_prefix <- function(step) {
    switch(step %||% "day", hour = "hr", day = "day", month = "mo", year = "yr",
           "day")
}

direction_short <- function(direction) {
    c(above = "abv", below = "blw")[[direction]]
}

#' Prefix of excess columns, after the unit: "K_abv_30", "mm_abv_20"
#' @noRd
excess_prefix <- function(unit) {
    unit <- canonical_unit(unit)
    if (is.null(unit)) {
        return("unit")
    }
    gsub("[^A-Za-z0-9]", "", split_rate(unit)$base)
}

#' The spell column that goes with a flag column
#' @noRd
spell_name <- function(flag) {
    if (grepl("^(day|hr|mo|yr)_", flag)) sub("^[a-z]+_", "spell_", flag) else paste0("spell_", flag)
}

#' Flag columns of a table: from the registry, else by their v1 names
#' @noRd
flag_columns <- function(data, meta) {
    registered <- names(purrr::keep(meta$indicators, \(entry) identical(entry$kind, "flag")))
    registered <- intersect(registered, names(data))
    if (length(registered) > 0) {
        return(registered)
    }
    candidates <- grep("^(day|hr|mo|yr)_(abv|blw)_", names(data), value = TRUE)
    candidates[vapply(data[candidates], is.logical, logical(1))]
}

#' Spell columns of a table: from the registry, else by their v1 names
#' @noRd
spell_columns <- function(data, meta) {
    registered <- names(purrr::keep(meta$indicators, \(entry) identical(entry$kind, "spell")))
    registered <- intersect(registered, names(data))
    if (length(registered) > 0) {
        return(registered)
    }
    grep("^spell_(abv|blw)_", names(data), value = TRUE)
}

# ==== Running a step ====================================================== ----

#' Run an indicator computation, split by unit when it would not fit
#'
#' `compute(x)` returns a long c4e_tbl; it must not record history, so the
#' pieces of a split share theirs. The step is recorded once, at the end.
#'
#' @param n_new Number of columns the step adds, for the memory estimate.
#' @noRd
run_indicator <- function(x, compute, fn_name, args, n_new, id = NULL,
                          label = NULL, chunk = "auto", started = Sys.time(),
                          call = rlang::caller_env()) {
    meta <- c4e_meta(x) %||% empty_meta()
    if (!is.null(label)) {
        c4e_progress_step("{fn_name}: {label}", .envir = environment())
    }
    key <- resolve_key(x, id)
    id_cols <- unique(c(key, intersect(meta$unit_cols, names(x))))
    n_dates <- sum(grepl(date_pattern(), names(x)))
    n_rows <- if (n_dates > 0) nrow(x) * n_dates else nrow(x)
    estimate <- estimate_bytes(n_rows, ncol(x) - n_dates + n_new + 2)

    out <- with_chunks(x, compute, by = id_cols, chunk = chunk,
                       mem_estimate = estimate, label = fn_name,
                       what = "units", call = call)
    out_meta <- c4e_meta(out)
    order_cols <- intersect(c(id_cols, out_meta$date_col %||% "date", "month"),
                            names(out))
    data <- sort_long(tibble::as_tibble(out), order_cols)
    new_c4e_tbl(data, c4e_record(out_meta, fn_name, args, started))
}

#' Write new indicator columns and their registry entries onto a frame
#' @noRd
finish_frame <- function(frame, columns, entries, meta_changes = list()) {
    data <- frame_columns(frame, columns)
    meta <- frame$meta
    meta$indicators[names(entries)] <- entries
    meta <- modify_meta(meta, meta_changes)
    new_c4e_tbl(data, meta)
}
