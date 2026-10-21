# Attribute operations on SpatVectors with terra alone (chunk 14 dropped
# tidyterra from Imports).

#' Rename attributes: `mapping` is c(new = "old"); missing old names are
#' skipped
#' @noRd
vect_rename <- function(x, mapping) {
    columns <- names(x)
    for (new in names(mapping)) {
        columns[columns == mapping[[new]]] <- new
    }
    names(x) <- columns
    x
}

#' Keep only the attributes `cols`, in that order
#' @noRd
vect_select <- function(x, cols) {
    x[, intersect(cols, names(x))]
}

#' Put the attributes `cols` first
#' @noRd
vect_front <- function(x, cols) {
    cols <- intersect(cols, names(x))
    x[, c(cols, setdiff(names(x), cols))]
}

#' Add the columns of a data frame to a SpatVector, matched on their shared
#' columns; features keep their order, unmatched ones get NA
#' @noRd
vect_join <- function(x, df) {
    by <- intersect(names(x), names(df))
    key <- function(d) do.call(paste, c(lapply(d[by], as.character), sep = "\r"))
    rows <- match(key(terra::values(x)), key(df))
    for (col in setdiff(names(df), by)) {
        x[[col]] <- df[[col]][rows]
    }
    x
}

#' Number the features in a first `ID_adm_div` attribute
#' @noRd
with_adm_id <- function(x) {
    x$ID_adm_div <- as.character(seq_len(nrow(x)))
    vect_front(x, "ID_adm_div")
}

#' Check that the optional packages of a coverage-weighted extraction are
#' installed
#' @noRd
need_exactextractr <- function(call = rlang::caller_env()) {
    rlang::check_installed(c("exactextractr", "sf"),
                           reason = "to weight cells by their coverage of polygons.",
                           call = call)
}
