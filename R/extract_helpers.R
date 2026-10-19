# Shared by the extract_*() functions (plan §8 chunk 5, §9.5, §10.4, §14).

# ==== CRS ================================================================= ----

#' A short name for a CRS, e.g. "EPSG:4326", or NULL when there is none
#' @noRd
crs_label <- function(x) {
    if (!nzchar(terra::crs(x))) {
        return(NULL)
    }
    described <- terra::crs(x, describe = TRUE)
    if (!is.na(described$authority) && !is.na(described$code)) {
        return(paste0(described$authority, ":", described$code))
    }
    terra::crs(x, proj = TRUE)
}

#' Locations and raster must be in the same CRS
#' @noRd
check_same_crs <- function(raster, vector, arg = "coord",
                           call = rlang::caller_env()) {
    if (!nzchar(terra::crs(vector))) {
        cli::cli_abort(
            c("{.arg {arg}} has no CRS.",
              "i" = "Set it when building the locations, e.g.
                     {.code georef_coord(crs = \"EPSG:4326\")}."),
            call = call)
    }
    if (nzchar(terra::crs(raster)) && !terra::same.crs(raster, vector)) {
        raster_crs <- crs_label(raster)
        vector_crs <- crs_label(vector)
        cli::cli_abort(
            c("The raster and {.arg {arg}} are in different CRS:
               {.val {raster_crs}} and {.val {vector_crs}}.",
              "i" = "Project the locations first, e.g.
                     {.code terra::project({arg}, raster)}."),
            call = call)
    }
    invisible(TRUE)
}

as_spat_vector <- function(x) {
    if (inherits(x, "SpatVector")) x else terra::vect(x)
}

# ==== Missing data ======================================================== ----

#' Warn about locations that got no value at all
#' @noRd
report_missing_points <- function(coord, raster, values, ids,
                                  call = rlang::caller_env()) {
    if (nrow(values) == 0 || ncol(values) == 0) {
        return(invisible(NULL))
    }
    xy <- terra::crds(coord)
    box <- terra::ext(raster)
    outside <- xy[, 1] < box$xmin | xy[, 1] > box$xmax |
        xy[, 2] < box$ymin | xy[, 2] > box$ymax
    empty <- rowSums(!is.na(as.matrix(values))) == 0 & !outside
    n_outside <- sum(outside)
    n_empty   <- sum(empty)
    if (n_outside + n_empty == 0) {
        return(invisible(NULL))
    }

    n <- length(ids)
    n_bad <- n_outside + n_empty
    bad_ids <- utils::head(ids[outside | empty], 5)
    more <- if (n_bad > 5) ", ..." else ""
    cli::cli_warn(
        c("{n_bad} of {n} location{?s} {cli::qty(n_bad)}{?has/have} no data in
           the raster.",
          "*" = if (n_outside > 0) "{n_outside} {?lies/lie} outside the raster.",
          "*" = if (n_empty > 0) "{n_empty} {?falls/fall} on cells missing in every
                                  layer.",
          "i" = "Identifiers: {.val {bad_ids}}{more}.",
          "i" = if (n_empty > 0) "Missing cells can be filled from their
                                   neighbours with {.fn fill_missing_rast}."),
        call = call)
}

# ==== Summaries =========================================================== ----

#' The spatial summary that fits the raster's kind, and why
#' @noRd
default_space_fn <- function(meta) {
    name <- meta$variable %||% "the values"
    switch(meta$kind %||% "unknown",
           categorical = list(fn = "mode", reason = paste(name, "is categorical")),
           count       = list(fn = "sum",  reason = paste(name, "is a count")),
           continuous  = list(fn = "mean", reason = paste(name, "is a level")),
           list(fn = "mean", reason = NULL))
}

#' The function terra::extract() applies for a summary name
#' @noRd
terra_summary <- function(fn) {
    if (identical(fn, "mode")) {
        return(function(x, na.rm = TRUE) {
            x <- x[!is.na(x)]
            if (length(x) == 0) NA else calc_mode(x)
        })
    }
    fn
}

# ==== Metadata ============================================================ ----

#' Metadata of an extracted table, from the raster's context
#' @noRd
extraction_meta <- function(raster, data, key, unit_cols, spatial_agg,
                            fn_name, args, started) {
    raster_context <- raster_meta(raster)
    has_dates <- any(grepl(date_pattern(), names(data)))
    unit_cols <- intersect(unit_cols, names(data))
    meta <- modify_meta(empty_meta(), list(
        key         = if (!is.null(key) && key %in% names(data)) key,
        unit_cols   = if (length(unit_cols) > 0) unit_cols,
        variable    = raster_context$variable,
        unit        = raster_context$unit,
        time_step   = raster_context$time_step,
        shape       = if (has_dates) "wide" else "summary",
        date_range  = if (has_dates) raster_context$date_range,
        crs         = crs_label(raster),
        source      = raster_context$source,
        label       = raster_context$label,
        spatial_agg = spatial_agg
    ))
    c4e_record(meta, fn_name, args, started)
}

key_or_null <- function(x, id) {
    tryCatch(resolve_key(x, id), error = function(e) NULL)
}

#' Column names for a raster's layers: the layer names, with "." as "_"
#' @noRd
layer_columns <- function(raster) {
    gsub("\\.", "_", names(raster))
}

#' Name the last columns of a table after the raster's layers
#'
#' terra sanitises attribute names when binding values to a SpatVector
#' ("2021-01-01" becomes "X2021.01.01"), so the value columns, which come
#' last, are named from the layers directly.
#' @noRd
name_value_columns <- function(data, raster) {
    n <- terra::nlyr(raster)
    positions <- seq.int(ncol(data) - n + 1, ncol(data))
    names(data)[positions] <- layer_columns(raster)
    data
}

# ==== Blocks of layers ==================================================== ----

#' Extract a raster in blocks of layers when the result would not fit
#'
#' `extract_fn(layers, first)` extracts the given layers; on the first block
#' it returns the identifying columns too, on the others only the values,
#' in the same row order, so the blocks are bound side by side.
#'
#' @param n_rows Expected number of rows of the result.
#' @param chunk `"auto"`, `FALSE`, or a whole number of layers per block.
#' @noRd
extract_in_blocks <- function(raster, n_rows, extract_fn, chunk = "auto",
                              label = "Extraction", call = rlang::caller_env()) {
    check_chunk(chunk, call)
    n_layers <- terra::nlyr(raster)
    estimate <- estimate_bytes(n_rows, n_layers)
    budget   <- mem_budget()
    whole    <- function() extract_fn(raster, first = TRUE)

    if (isFALSE(chunk)) {
        if (estimate > budget) {
            size <- format_bytes(estimate)
            limit <- format_bytes(budget)
            cli::cli_abort(
                c("{label} needs about {size}, more than the memory budget of
                   {limit}.",
                  "i" = "Allow blocks of layers with {.code chunk = \"auto\"}."),
                call = call)
        }
        return(whole())
    }
    per_block <- if (identical(chunk, "auto")) {
        if (estimate <= budget) return(whole())
        max(1, floor(n_layers * budget / estimate))
    } else {
        as.integer(chunk)
    }
    blocks <- split(seq_len(n_layers), ceiling(seq_len(n_layers) / per_block))
    if (length(blocks) <= 1) {
        return(whole())
    }

    if (identical(chunk, "auto")) {
        size  <- format_bytes(estimate)
        limit <- format_bytes(budget)
        c4e_inform(c(
            "i" = "{label} needs about {size} ({n_rows} rows by {n_layers}
                   layers); the memory budget is {limit}.",
            " " = "Extracting in {length(blocks)} blocks of up to {per_block}
                   layers."
        ))
    } else {
        c4e_inform(c(
            "i" = "{label}: extracting {n_layers} layers in {length(blocks)}
                   blocks of up to {per_block}."
        ))
    }

    pieces <- run_pieces(blocks, \(layers) {
        extract_fn(raster[[layers]], first = identical(layers, blocks[[1]]))
    }, label)
    dplyr::bind_cols(pieces)
}
