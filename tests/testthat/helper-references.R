# Reference outputs of the v1 functions (plan §8 chunk 13).
#
# The v1 functions that c4e replaced were removed in chunk 13; they live on
# in climatic4economist 0.1. Their outputs on the fixtures are kept in
# fixtures/v1_reference.rds, so the tests still check that the new functions
# give the same numbers. Each `v1_ref()` call keeps the v1 expression that
# produced its reference, as a record. The expression is evaluated only when
# recording: set C4E_RECORD_V1=true and run the tests on a commit where the
# v1 functions exist (before chunk 13, or with climatic4economist attached).

v1_reference_path <- function() {
    testthat::test_path("fixtures", "v1_reference.rds")
}

v1_reference_store <- new.env(parent = emptyenv())

#' The stored v1 output called `name`; with C4E_RECORD_V1=true, evaluate
#' `expr`, keep the columns `keep` (all when NULL) and store it
#' @noRd
v1_ref <- function(name, expr, keep = NULL) {
    path <- v1_reference_path()
    if (identical(Sys.getenv("C4E_RECORD_V1"), "true")) {
        value <- expr
        if (!is.null(keep)) {
            value <- tibble::as_tibble(value)[intersect(keep, names(value))]
        }
        store <- if (file.exists(path)) readRDS(path) else list()
        store[[name]] <- value
        saveRDS(store, path, compress = "xz")
        return(value)
    }
    if (is.null(v1_reference_store$values)) {
        v1_reference_store$values <- readRDS(path)
    }
    if (!name %in% names(v1_reference_store$values)) {
        stop("No v1 reference called '", name, "'; record it with C4E_RECORD_V1=true.")
    }
    v1_reference_store$values[[name]]
}
