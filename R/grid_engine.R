# The engine behind the grid methods and wrappers (plan §13). A raster is
# read in blocks of rows; each block becomes a table of cells by dates and
# goes through the same step functions as extracted survey data, so a cell's
# numbers are those the table path gives. The results are written back as
# layers, one per indicator and period, and the context travels in GeoTIFF
# tags, which extract_*() reads back into the table's metadata.

# ==== Blocks ================================================================ ----

#' Run table steps on every cell of one or more rasters, block by block
#'
#' @param rasters A named list of `SpatRaster`s with the same geometry; the
#'   first is the template of the result.
#' @param compute A function of a named list of wide `c4e_tbl`s (one per
#'   raster, cells keyed by `ID`) returning a `c4e_tbl` with `ID`, optionally
#'   a slice column (a date, period or month) and the indicator columns.
#' @param grid_fn,grid_args The wrapper's name and arguments, kept in the tags
#'   for the history.
#' @param filename,overwrite,wopt Output file, as in [terra::writeRaster()].
#' @param rows_per_block Raster rows per block; by default from the memory
#'   budget.
#' @param label Name shown on the progress bar.
#' @noRd
grid_apply <- function(rasters, compute, grid_fn, grid_args = list(),
                       filename = "", overwrite = FALSE, wopt = list(),
                       rows_per_block = NULL, label = NULL,
                       call = rlang::caller_env()) {
    template <- rasters[[1]]
    for (name in names(rasters)[-1]) {
        if (!terra::compareGeom(template, rasters[[name]], stopOnError = FALSE)) {
            cli::cli_abort("{.arg {name}} must have the same extent, resolution and
                            CRS as the first raster.", call = call)
        }
    }
    if (nzchar(filename) && file.exists(filename) && !isTRUE(overwrite)) {
        cli::cli_abort("{.file {filename}} exists; use {.code overwrite = TRUE}.",
                       call = call)
    }
    metas <- lapply(rasters, raster_meta)
    columns <- lapply(rasters, block_columns)

    n_row <- terra::nrow(template)
    if (is.null(rows_per_block)) {
        n_layers <- sum(vapply(rasters, terra::nlyr, numeric(1)))
        # a block's long tables hold each value with its indicators and dates
        cells <- mem_budget() / (n_layers * 8 * 25)
        rows_per_block <- max(1, min(n_row, floor(cells / terra::ncol(template))))
    }
    starts <- seq.int(1, n_row, by = rows_per_block)
    n_rows <- pmin(rows_per_block, n_row - starts + 1)
    n_blocks <- length(starts)

    for (r in rasters) terra::readStart(r)
    on.exit(for (r in rasters) terra::readStop(r), add = TRUE)

    verbose <- c4e_verbose()
    if (verbose && n_blocks > 1) {
        c4e_inform("Processing {n_blocks} blocks of raster rows.")
        bar <- cli::cli_progress_bar(label %||% "Grid", total = n_blocks,
                                     .envir = environment())
    }
    warnings <- character()
    run_block <- function(i) {
        values <- lapply(rasters, \(r) terra::readValues(r, row = starts[i],
                                                         nrows = n_rows[i], mat = TRUE))
        n_cells <- nrow(values[[1]])
        with_data <- Reduce(`&`, lapply(values, \(v) rowSums(!is.na(v)) > 0))
        if (!any(with_data)) {
            return(list(result = NULL, n_cells = n_cells))
        }
        tables <- Map(\(v, cols, meta) {
            block_table(v[with_data, , drop = FALSE], which(with_data), cols, meta)
        }, values, columns, metas)
        old <- options(c4e.verbose = FALSE)
        on.exit(options(old), add = TRUE)
        result <- withCallingHandlers(
            compute(tables),
            warning = function(w) {
                warnings <<- c(warnings, conditionMessage(w))
                invokeRestart("muffleWarning")
            })
        list(result = result, n_cells = n_cells)
    }

    layout <- NULL
    out <- NULL
    pending <- 0
    temp_file <- if (nzchar(filename)) tempfile(fileext = ".tif") else ""
    for (i in seq_len(n_blocks)) {
        block <- run_block(i)
        if (is.null(layout) && !is.null(block$result)) {
            layout <- grid_layout(block$result, metas[[1]])
            out <- terra::rast(template, nlyrs = length(layout$names))
            names(out) <- layout$names
            do.call(terra::writeStart,
                    c(list(out, filename = temp_file, overwrite = TRUE), wopt))
            for (j in seq_len(pending)) {
                terra::writeValues(out, matrix(NA_real_, n_rows[j] * terra::ncol(template),
                                               length(layout$names)),
                                   starts[j], n_rows[j])
            }
        }
        if (is.null(layout)) {
            pending <- pending + 1
        } else {
            terra::writeValues(out, grid_matrix(block$result, block$n_cells, layout),
                               starts[i], n_rows[i])
        }
        if (verbose && n_blocks > 1) cli::cli_progress_update(id = bar)
    }
    if (is.null(layout)) {
        cli::cli_abort("No cell of the raster has data.", call = call)
    }
    out <- terra::writeStop(out)
    if (verbose && n_blocks > 1) cli::cli_progress_done(id = bar)
    for (message in unique(warnings)) {
        cli::cli_warn(message, call = call)
    }

    out <- describe_grid(out, layout, metas[[1]], grid_fn, grid_args)
    if (nzchar(filename)) {
        out <- do.call(terra::writeRaster,
                       c(list(out, filename = filename, overwrite = TRUE), wopt))
        unlink(temp_file)
    }
    out
}

#' Column names of a raster's layers in a block table: the dates when the
#' raster is dated, else the layer names
#' @noRd
block_columns <- function(r) {
    if (terra::has.time(r) && !anyNA(terra::time(r))) {
        return(format(as.Date(terra::time(r))))
    }
    layer_columns(r)
}

#' A block of cells as the wide table extract_*() would give
#' @noRd
block_table <- function(values, cells, columns, meta) {
    colnames(values) <- columns
    data <- tibble::as_tibble(as.data.frame(values, check.names = FALSE))
    data <- tibble::add_column(data, ID = as.character(cells), .before = 1)
    has_dates <- any(grepl(date_pattern(), columns))
    new_c4e_tbl(data, modify_meta(empty_meta(), list(
        key        = "ID",
        variable   = meta$variable,
        unit       = meta$unit,
        time_step  = meta$time_step,
        shape      = if (has_dates) "wide" else "summary",
        date_range = if (has_dates) meta$date_range,
        source     = meta$source,
        label      = meta$label
    )))
}

#' Which layers a result gives: one per indicator column and slice
#' @noRd
grid_layout <- function(result, raster_context) {
    meta <- c4e_meta(result)
    data <- tibble::as_tibble(result)
    cols <- intersect(names(meta$indicators), names(data))
    slice <- if (!is.null(meta$date_col) && meta$date_col %in% names(data)) {
        meta$date_col
    } else if (identical(meta$shape, "lookup") && "month" %in% names(data)) {
        "month"
    }
    slices <- if (!is.null(slice)) sort(unique(data[[slice]]))
    step <- meta$time_step
    slice_type <- if (is.null(slice)) "none" else if (inherits(slices, "Date")) "date" else "text"
    labels <- if (is.null(slice)) {
        NULL
    } else if (slice_type == "date") {
        format(slices, switch(step %||% "day", year = "%Y", month = "%Y-%m", "%Y-%m-%d"))
    } else {
        as.character(slices)
    }
    n_slices <- max(1, length(slices))
    list(
        cols       = cols,
        slice      = slice,
        slice_type = slice_type,
        slices     = slices,
        names      = if (is.null(slice)) cols else paste0(rep(cols, each = n_slices), "_",
                                                         rep(labels, times = length(cols))),
        layer_col  = rep(cols, each = n_slices),
        entries    = meta$indicators[cols],
        time_step  = step,
        variable   = meta$variable %||% raster_context$variable,
        unit       = meta$unit %||% raster_context$unit
    )
}

#' A block's result as a cells-by-layers matrix
#' @noRd
grid_matrix <- function(result, n_cells, layout) {
    data <- tibble::as_tibble(result)
    out <- matrix(NA_real_, n_cells, length(layout$names))
    rows <- as.integer(data$ID)
    n_slices <- max(1, length(layout$slices))
    position <- if (is.null(layout$slice)) {
        rep(1L, nrow(data))
    } else {
        match(data[[layout$slice]], layout$slices)
    }
    known <- !is.na(position) & !is.na(rows)
    for (k in seq_along(layout$cols)) {
        layer <- (k - 1L) * n_slices + position
        out[cbind(rows[known], layer[known])] <- as.numeric(data[[layout$cols[k]]][known])
    }
    out
}

# ==== Tags ================================================================== ----

#' Names, dates, units and tags of a grid result
#' @noRd
describe_grid <- function(out, layout, raster_context, grid_fn, grid_args) {
    names(out) <- layout$names
    if (layout$slice_type == "date") {
        terra::time(out) <- rep(as.Date(layout$slices), times = length(layout$cols))
    }
    terra::units(out) <- vapply(layout$layer_col, \(col) {
        grid_unit(layout$entries[[col]], layout$time_step)
    }, character(1), USE.NAMES = FALSE)
    out <- set_raster_meta(out, list(
        variable = layout$variable, source = raster_context$source,
        label = raster_context$label, time_step = layout$time_step))
    tags <- c(
        c4e_grid            = grid_fn,
        c4e_grid_args       = encode_fields(grid_args),
        c4e_grid_cols       = paste(vapply(layout$cols, utils::URLencode, character(1),
                                           reserved = TRUE), collapse = ","),
        c4e_grid_slice      = layout$slice %||% "",
        c4e_grid_slice_type = layout$slice_type,
        c4e_grid_step       = layout$time_step %||% "",
        c4e_grid_unit       = layout$unit %||% "",
        stats::setNames(vapply(layout$entries, encode_fields, character(1)),
                        paste0("c4e_grid_ind_", seq_along(layout$cols)))
    )
    existing <- terra::metags(out)
    kept <- if (is.data.frame(existing) && nrow(existing) > 0) {
        existing <- existing[startsWith(existing$name, "c4e_") &
                                 !startsWith(existing$name, "c4e_grid"), , drop = FALSE]
        stats::setNames(existing$value, existing$name)
    }
    terra::metags(out) <- c(kept, tags)
    out
}

#' The unit of a grid layer, from its registry entry
#' @noRd
grid_unit <- function(entry, step) {
    kind <- if (identical(entry$kind, "agg")) entry$of %||% "flag" else entry$kind
    stat <- entry$stat %||% ""
    if (identical(stat, "n")) return("spells")
    switch(kind,
           flag  = , spell = step_word(entry$step %||% step_of_period(step)),
           excess = entry$unit %||% "",
           std   = "",
           entry$unit %||% "")
}

step_of_period <- function(step) {
    if (isTRUE(step %in% c("year", "month"))) "day" else step
}

#' Registry entries and arguments as tag text: atomic fields only, typed,
#' URL-encoded (terra splits tag values on "=")
#' @noRd
encode_fields <- function(fields) {
    fields <- fields[vapply(fields, \(v) is.atomic(v) && length(v) > 0, logical(1))]
    if (length(fields) == 0) return("")
    parts <- vapply(names(fields), \(name) {
        v <- fields[[name]]
        type <- if (is.logical(v)) "l" else if (is.integer(v)) "i" else
            if (is.numeric(v)) "n" else "c"
        text <- vapply(as.character(v), utils::URLencode, character(1),
                       reserved = TRUE)
        paste0(name, ":", type, ":", paste(text, collapse = ","))
    }, character(1))
    utils::URLencode(paste(parts, collapse = ";"), reserved = TRUE)
}

#' The reverse of encode_fields()
#' @noRd
decode_fields <- function(text) {
    text <- utils::URLdecode(text %||% "")
    if (!nzchar(text)) return(list())
    out <- list()
    for (part in strsplit(text, ";", fixed = TRUE)[[1]]) {
        pieces <- strsplit(part, ":", fixed = TRUE)[[1]]
        if (length(pieces) < 3) next
        name <- pieces[1]
        type <- pieces[2]
        raw <- paste(pieces[-(1:2)], collapse = ":")
        values <- vapply(strsplit(raw, ",", fixed = TRUE)[[1]], utils::URLdecode,
                         character(1), USE.NAMES = FALSE)
        values[values == "NA"] <- NA
        out[[name]] <- switch(type,
                              l = as.logical(values),
                              i = as.integer(values),
                              n = as.numeric(values),
                              values)
    }
    out
}

#' The grid description stored on a raster, or NULL for other rasters
#' @noRd
read_grid_meta <- function(raster) {
    tags <- tryCatch(terra::metags(raster), error = function(e) NULL)
    if (!is.data.frame(tags) || !"c4e_grid" %in% tags$name) {
        return(NULL)
    }
    tag <- function(name) {
        value <- tags$value[tags$name == name]
        if (length(value) == 0 || !nzchar(value[1])) NULL else value[1]
    }
    cols <- vapply(strsplit(tag("c4e_grid_cols") %||% "", ",", fixed = TRUE)[[1]],
                   utils::URLdecode, character(1), USE.NAMES = FALSE)
    entries <- lapply(seq_along(cols), \(i) decode_fields(tag(paste0("c4e_grid_ind_", i))))
    names(entries) <- cols
    list(
        fn         = tag("c4e_grid"),
        args       = decode_fields(tag("c4e_grid_args")),
        cols       = cols,
        entries    = entries,
        slice      = tag("c4e_grid_slice"),
        slice_type = tag("c4e_grid_slice_type") %||% "none",
        time_step  = tag("c4e_grid_step"),
        unit       = tag("c4e_grid_unit")
    )
}

#' Turn an extraction of a grid result back into the table it came from
#'
#' The extracted value columns (one per layer, last) are regrouped by
#' indicator and slice, so the table has the identifiers, the slice (period,
#' date or month) and one column per indicator, with the registry restored.
#' @noRd
restore_grid_table <- function(out, raster) {
    info <- read_grid_meta(raster)
    if (is.null(info) || length(info$cols) == 0) {
        return(out)
    }
    data <- tibble::as_tibble(out)
    n <- terra::nlyr(raster)
    value_pos <- seq.int(ncol(data) - n + 1, ncol(data))
    id_cols <- names(data)[-value_pos]
    layer_names <- names(raster)
    by_length <- info$cols[order(-nchar(info$cols))]
    layer_col <- vapply(layer_names, \(name) {
        hit <- by_length[name == by_length | startsWith(name, paste0(by_length, "_"))]
        if (length(hit) == 0) NA_character_ else hit[1]
    }, character(1), USE.NAMES = FALSE)
    if (anyNA(layer_col)) {
        # renamed layers: the tags no longer describe them
        return(out)
    }

    slice <- info$slice
    result <- if (info$slice_type == "none") {
        restored <- data[id_cols]
        for (i in seq_len(n)) restored[[layer_col[i]]] <- data[[value_pos[i]]]
        sort_long(restored, id_cols)
    } else {
        layer_slice <- if (info$slice_type == "date") {
            as.Date(terra::time(raster))
        } else {
            substring(layer_names, nchar(layer_col) + 2)
        }
        slices <- sort(unique(layer_slice))
        parts <- lapply(seq_along(slices), \(k) {
            part <- data[id_cols]
            part[[slice]] <- rep(slices[k], nrow(part))
            for (i in which(layer_slice == slices[k])) {
                part[[layer_col[i]]] <- data[[value_pos[i]]]
            }
            part
        })
        sort_long(dplyr::bind_rows(parts), c(id_cols, slice))
    }
    result <- result[c(id_cols, if (info$slice_type != "none") slice,
                       intersect(info$cols, names(result)))]

    meta <- c4e_meta(out)
    grid_entry <- list(fn = info$fn, args = info$args)
    meta <- modify_meta(meta, list(
        shape      = switch(info$slice_type, date = "long", text = "lookup", "summary"),
        date_col   = if (info$slice_type == "date") slice,
        time_step  = info$time_step,
        unit       = info$unit,
        date_range = if (info$slice_type == "date") range(result[[slice]]),
        indicators = info$entries
    ))
    meta$history <- c(list(grid_entry), meta$history)
    new_c4e_tbl(result, prune_meta(meta, names(result)))
}
