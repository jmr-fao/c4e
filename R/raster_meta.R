# Package metadata on rasters (plan §2, §13).
#
# terra offers two places to keep text with a raster, and neither suffices
# alone (probed on terra 1.9.46):
# * metags() survive writing and reading a GeoTIFF, but are dropped by
#   subsetting (r[[1:5]]), arithmetic and rotate();
# * varnames() and longnames() survive subsetting, arithmetic, crop() and
#   subst(), but are replaced or emptied when a file is read back. They are
#   kept per data source, so arithmetic on a raster built from several files
#   (one new source) drops them too.
# So the metadata is written to both, and read from whichever is present.
# Units and dates live in terra's own units() and time(), which survive both.

raster_meta_fields <- c("variable", "kind", "source", "label", "time_step")
raster_meta_prefix <- "c4e:"

#' Write the package metadata onto a raster
#'
#' @param x A `SpatRaster`.
#' @param meta A list with any of `variable`, `kind`, `source`, `label`,
#'   `time_step`. `NULL` entries are cleared.
#' @noRd
set_raster_meta <- function(x, meta) {
    meta <- meta[intersect(names(meta), raster_meta_fields)]
    meta <- purrr::compact(meta)
    values <- vapply(meta, \(value) as.character(value)[1], character(1))

    # on disk: one tag per field; "" marks a cleared field
    tags <- stats::setNames(rep("", length(raster_meta_fields)),
                            paste0("c4e_", raster_meta_fields))
    if (length(values) > 0) {
        tags[paste0("c4e_", names(values))] <- values
    }
    terra::metags(x) <- tags

    # in memory: one encoded string; longnames belong to each data source,
    # and a single value is given to all of them
    encoded <- paste0(
        raster_meta_prefix,
        paste(names(values), vapply(values, utils::URLencode, character(1),
                                    reserved = TRUE),
              sep = "=", collapse = ";")
    )
    terra::longnames(x) <- encoded
    if (!is.null(meta$variable)) {
        terra::varnames(x) <- meta$variable
    }
    x
}

#' Metadata stored on a raster by the package, without inference
#' @noRd
stored_raster_meta <- function(x) {
    meta <- stats::setNames(vector("list", length(raster_meta_fields)),
                            raster_meta_fields)

    encoded <- unique(terra::longnames(x))
    encoded <- encoded[!is.na(encoded) & startsWith(encoded, raster_meta_prefix)]
    if (length(encoded) > 0) {
        pairs <- strsplit(sub(raster_meta_prefix, "", encoded[1], fixed = TRUE),
                          ";", fixed = TRUE)[[1]]
        pairs <- strsplit(pairs[nzchar(pairs)], "=", fixed = TRUE)
        for (pair in pairs) {
            if (length(pair) == 2 && pair[1] %in% raster_meta_fields) {
                meta[pair[1]] <- list(utils::URLdecode(pair[2]))
            }
        }
        return(meta)
    }

    tags <- tryCatch(terra::metags(x), error = function(e) NULL)
    if (is.data.frame(tags) && nrow(tags) > 0) {
        for (field in raster_meta_fields) {
            value <- tags$value[tags$name == paste0("c4e_", field)]
            if (length(value) > 0 && nzchar(value[1])) {
                meta[field] <- list(value[1])
            }
        }
    }
    meta
}

#' Context recorded on a raster
#'
#' Returns what [read_climate()] and the other package steps recorded about a
#' raster: the variable, its kind, the data source and a label, along with
#' the unit and dates kept by terra itself. The time step is inferred from
#' the dates when it was not recorded.
#'
#' The context survives subsetting, arithmetic and cropping in memory, and
#' writing to and reading from a GeoTIFF. Rasters read with
#' [terra::rast()] carry it only until their first subset; read them with
#' [read_climate()] to keep it throughout.
#'
#' @param x A `SpatRaster`.
#'
#' @return A list with `variable`, `unit`, `time_step`, `kind`, `source`,
#'   `label` and `date_range`; fields that are unknown are `NULL`.
#'
#' @seealso [read_climate()]
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "climatic4economist"))
#' raster_meta(tmax)[c("variable", "unit", "time_step")]
raster_meta <- function(x) {
    if (!inherits(x, "SpatRaster")) {
        cli::cli_abort("{.arg x} must be a {.cls SpatRaster}.")
    }
    meta  <- stored_raster_meta(x)
    dates <- if (terra::has.time(x)) terra::time(x)
    list(
        variable   = meta$variable,
        unit       = canonical_unit(raster_unit(x)),
        time_step  = meta$time_step %||% infer_time_step(dates),
        kind       = meta$kind,
        source     = meta$source,
        label      = meta$label,
        date_range = if (!is.null(dates) && !all(is.na(dates))) {
            range(as.Date(dates), na.rm = TRUE)
        }
    )
}

#' Copy the package metadata, layer names, dates and unit from one raster to
#' another, for terra operations that drop them
#' @noRd
keep_raster_meta <- function(out, x) {
    if (terra::nlyr(out) == terra::nlyr(x)) {
        names(out) <- names(x)
        if (terra::has.time(x)) {
            terra::time(out) <- terra::time(x)
        }
    }
    unit <- raster_unit(x)
    if (!is.null(unit)) {
        terra::units(out) <- unit
    }
    set_raster_meta(out, stored_raster_meta(x))
}
