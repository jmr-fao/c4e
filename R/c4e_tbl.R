#' Tables that carry their context
#'
#' @description
#' Functions of climatic4economist return `c4e_tbl` objects: tibbles with one
#' extra attribute, the *metadata*, recording the context of the data. The
#' context includes the key column, the variable and its unit, the time step,
#' the date range and the CRS. It also holds a registry describing every
#' indicator column, such as its threshold, direction, percentile or spell
#' length. Later steps of a pipeline read their defaults from it, so a value
#' given once does not have to be typed again.
#'
#' A `c4e_tbl` behaves like any tibble. Row and column verbs (`mutate()`,
#' `filter()`, `select()`, `rename()`, joins, `bind_rows()`, `[`, grouped
#' operations) keep the metadata. Dropping a column removes it from the
#' registry, and renaming a column renames it in the registry. Verbs that
#' change what the rows mean, such as `summarise()` and
#' `tidyr::pivot_longer()`, return a plain tibble. The package functions that
#' summarise rebuild the metadata themselves.
#'
#' When stacking tables, `dplyr::bind_rows()` keeps the metadata of the first
#' table only. `vctrs::vec_rbind()` merges the metadata of all of them. To
#' join indicator tables side by side, use [bind_indicators()].
#'
#' * `c4e_meta()` returns the metadata, or one field of it.
#' * `is_c4e_tbl()` tests for the class.
#' * `update_meta()` sets or clears fields. On a plain data frame it creates
#'   a `c4e_tbl`.
#' * `tibble::as_tibble()` removes the class and the metadata.
#'
#' @param x A data frame.
#' @param field Optional name of one metadata field.
#' @param .x A data frame or a `c4e_tbl`.
#' @param ... Named metadata fields to set. `NULL` clears a field.
#'
#' @return `c4e_meta()` returns a named list, one field, or `NULL` when `x`
#'   carries no metadata. `is_c4e_tbl()` returns `TRUE` or `FALSE`.
#'   `update_meta()` returns a `c4e_tbl`.
#'
#' @section Metadata fields:
#' * `key`: name of the column identifying the units, e.g. `ID`.
#' * `unit_cols`: further identifying columns, e.g. `x_cell`, `y_cell`.
#' * `variable`, `unit`: the base series, e.g. `"tmax"` in `"C"`.
#' * `time_step`: one of `"hour"`, `"day"`, `"month"`, `"year"`.
#' * `shape`: `"wide"` (one column per date), `"long"` (`date`, `value`),
#'   `"lookup"` (key by month) or `"summary"` (key, possibly by lag).
#' * `date_col`, `date_range`: the date column and the period covered.
#' * `crs`, `source`: coordinate reference system and data source.
#' * `indicators`: one entry per indicator column, giving its `kind` (`"flag"`,
#'   `"excess"`, `"spell"`, `"pct"`, `"std"`, `"par"` or `"agg"`) and the
#'   parameters it was computed with.
#' * `transform`, `spatial_agg`, `window`, `survey`, `survey_cols`, `history`,
#'   `label`, `id_rule`, `preset`: set by later steps of the pipeline.
#'
#' @name c4e_tbl
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = c("1", "2"), value = c(28, 33)),
#'   key = "ID", variable = "tmax", unit = "C", time_step = "day"
#' )
#' x
#' c4e_meta(x, "unit")
#'
#' # the context survives ordinary dplyr steps
#' dplyr::filter(x, value > 30) |> c4e_meta("variable")
NULL

# ==== Field definitions =================================================== ----

c4e_meta_fields <- c(
    "schema", "key", "unit_cols", "variable", "unit", "time_step", "shape",
    "date_col", "date_range", "crs", "source", "transform", "spatial_agg",
    "window", "survey", "survey_cols", "indicators", "history", "label",
    "id_rule", "preset"
)
c4e_time_steps      <- c("hour", "day", "month", "year")
c4e_shapes          <- c("wide", "long", "lookup", "summary")
c4e_indicator_kinds <- c("flag", "excess", "spell", "pct", "std", "par", "agg")
c4e_directions      <- c("above", "below")

# fields holding one value, which must agree when two tables are merged
c4e_single_fields <- c(
    "variable", "unit", "time_step", "shape", "date_col", "crs", "transform",
    "spatial_agg", "window", "survey", "label", "id_rule", "preset"
)
# fields holding a set of values, which are united when tables are merged
c4e_union_fields <- c("unit_cols", "survey_cols", "source")

# ==== Constructor, validator, helpers ===================================== ----

#' Metadata with every field present and unset
#' @noRd
empty_meta <- function() {
    meta <- rep(list(NULL), length(c4e_meta_fields))
    names(meta) <- c4e_meta_fields
    meta$schema     <- 1L
    meta$indicators <- list()
    meta$history    <- list()
    meta
}

#' Set fields of a metadata list; a NULL value clears the field
#' @noRd
modify_meta <- function(meta, changes) {
    meta <- meta %||% empty_meta()
    for (field in names(changes)) {
        meta[field] <- list(changes[[field]])
    }
    meta
}

#' Build a c4e_tbl
#'
#' Fields missing from `meta` are added unset. Grouped data frames keep their
#' grouping, with `c4e_tbl` placed first in the class.
#' @noRd
new_c4e_tbl <- function(x, meta = list(), call = rlang::caller_env()) {
    meta <- validate_meta(modify_meta(empty_meta(), meta), x, call = call)

    if (inherits(x, "grouped_df")) {
        attr(x, "c4e_meta") <- meta
        class(x) <- c("c4e_tbl", setdiff(class(x), "c4e_tbl"))
        return(x)
    }

    x <- tibble::as_tibble(x)
    tibble::new_tibble(x, c4e_meta = meta, nrow = nrow(x), class = "c4e_tbl")
}

#' Check that metadata is well formed and refers to existing columns
#' @noRd
validate_meta <- function(meta, x, call = rlang::caller_env()) {
    unknown <- setdiff(names(meta), c4e_meta_fields)
    if (length(unknown) > 0) {
        cli::cli_abort("Unknown metadata field{?s}: {.field {unknown}}.",
                       call = call)
    }
    cols <- names(x)

    for (field in c("key", "date_col", "variable", "unit", "crs", "label",
                    "id_rule", "preset")) {
        check_meta_string(meta[[field]], field, call)
    }
    for (field in c("key", "date_col")) {
        value <- meta[[field]]
        if (!is.null(value) && !value %in% cols) {
            cli::cli_abort(
                "The {.field {field}} {.val {value}} is not a column of the table.",
                call = call)
        }
    }
    for (field in c("unit_cols", "survey_cols")) {
        missing_cols <- setdiff(meta[[field]], cols)
        if (length(missing_cols) > 0) {
            cli::cli_abort(
                "The {.field {field}} {.val {missing_cols}} {?is/are} not
                 {?a column/columns} of the table.",
                call = call)
        }
    }
    if (!is.null(meta$time_step) && !isTRUE(meta$time_step %in% c4e_time_steps)) {
        cli::cli_abort(
            "{.field time_step} must be one of {.or {.val {c4e_time_steps}}}.",
            call = call)
    }
    if (!is.null(meta$shape) && !isTRUE(meta$shape %in% c4e_shapes)) {
        cli::cli_abort("{.field shape} must be one of {.or {.val {c4e_shapes}}}.",
                       call = call)
    }
    if (!is.null(meta$date_range) &&
        !(inherits(meta$date_range, "Date") && length(meta$date_range) == 2)) {
        cli::cli_abort("{.field date_range} must be two dates.", call = call)
    }

    indicators <- meta$indicators
    if (!is.list(indicators) ||
        (length(indicators) > 0 && !rlang::is_named(indicators))) {
        cli::cli_abort("{.field indicators} must be a list named by column.",
                       call = call)
    }
    missing_cols <- setdiff(names(indicators), cols)
    if (length(missing_cols) > 0) {
        cli::cli_abort(
            "Indicator{?s} {.field {missing_cols}} {?is/are} not
             {?a column/columns} of the table.",
            call = call)
    }
    for (name in names(indicators)) {
        validate_indicator(indicators[[name]], name, call)
    }

    meta
}

check_meta_string <- function(value, field, call) {
    if (!is.null(value) && !rlang::is_string(value)) {
        cli::cli_abort("{.field {field}} must be a single string.", call = call)
    }
}

#' Describe one indicator column for the registry
#'
#' @param kind One of `c4e_indicator_kinds`.
#' @param ... Parameters of the indicator, e.g. `base`, `direction`,
#'   `threshold`, `p`, `min_spell`, `scale`, `stat`, `period`, `step`,
#'   `variable`, `unit`. `NULL` values are dropped.
#' @noRd
new_indicator <- function(kind, ..., call = rlang::caller_env()) {
    entry <- purrr::compact(rlang::list2(kind = kind, ...))
    validate_indicator(entry, NULL, call)
}

validate_indicator <- function(entry, name, call) {
    what <- if (is.null(name)) "An indicator" else
        cli::format_inline("Indicator {.field {name}}")
    if (!is.list(entry) || !isTRUE(entry$kind %in% c4e_indicator_kinds)) {
        cli::cli_abort(
            "{what} needs a {.field kind}, one of {.or {.val {c4e_indicator_kinds}}}.",
            call = call)
    }
    if (!is.null(entry$direction) && !isTRUE(entry$direction %in% c4e_directions)) {
        cli::cli_abort(
            "{what} has {.field direction} {.val {entry$direction}};
             use {.or {.val {c4e_directions}}}.",
            call = call)
    }
    threshold <- entry$threshold
    if (!is.null(threshold) && !is.numeric(threshold) && !rlang::is_string(threshold)) {
        cli::cli_abort(
            "{what} needs a numeric {.field threshold} or the name of a
             lookup column.",
            call = call)
    }
    entry
}

#' Add or replace one indicator entry of a c4e_tbl
#' @noRd
add_indicator <- function(x, col, kind, ...) {
    meta <- c4e_meta(x) %||% empty_meta()
    meta$indicators[[col]] <- new_indicator(kind, ...)
    new_c4e_tbl(x, meta)
}

#' Drop metadata that refers to columns no longer in the table
#' @noRd
prune_meta <- function(meta, cols) {
    meta$indicators <- meta$indicators[intersect(names(meta$indicators), cols)]
    for (field in c("key", "date_col")) {
        if (!is.null(meta[[field]]) && !meta[[field]] %in% cols) {
            meta[field] <- list(NULL)
        }
    }
    for (field in c("unit_cols", "survey_cols")) {
        kept <- intersect(meta[[field]], cols)
        meta[field] <- list(if (length(kept) > 0) kept)
    }
    meta
}

#' Rebuild a c4e_tbl from an operation's result and the original table
#' @noRd
c4e_restore <- function(out, template) {
    meta <- c4e_meta(template)
    if (is.null(meta) || !is.data.frame(out)) {
        return(out)
    }
    new_c4e_tbl(out, prune_meta(meta, names(out)))
}

#' Follow a column rename through the metadata
#' @noRd
rename_meta <- function(meta, old, new) {
    if (is.null(meta)) {
        return(NULL)
    }
    lookup <- stats::setNames(as.character(new), old)
    rename <- function(value) {
        if (is.null(value)) {
            return(NULL)
        }
        hit <- value %in% old
        value[hit] <- lookup[value[hit]]
        unname(value)
    }

    for (field in c("key", "date_col", "unit_cols", "survey_cols")) {
        meta[field] <- list(rename(meta[[field]]))
    }
    if (length(meta$indicators) > 0) {
        names(meta$indicators) <- rename(names(meta$indicators))
        meta$indicators <- lapply(meta$indicators, \(entry) {
            entry$base <- rename(entry$base)
            if (is.character(entry$threshold)) {
                entry$threshold <- rename(entry$threshold)
            }
            entry
        })
    }
    if (!is.null(meta$window$interview)) {
        meta$window$interview <- rename(meta$window$interview)
    }
    meta
}

# ==== Exported accessors ================================================== ----

#' @rdname c4e_tbl
#' @export
c4e_meta <- function(x, field = NULL) {
    meta <- attr(x, "c4e_meta", exact = TRUE)
    if (is.null(field)) {
        return(meta)
    }
    if (!rlang::is_string(field) || !field %in% c4e_meta_fields) {
        cli::cli_abort("{.arg field} must be one of {.or {.val {c4e_meta_fields}}}.")
    }
    meta[[field]]
}

#' @rdname c4e_tbl
#' @export
is_c4e_tbl <- function(x) {
    inherits(x, "c4e_tbl")
}

#' @rdname c4e_tbl
#' @export
update_meta <- function(.x, ...) {
    changes <- rlang::list2(...)
    if (length(changes) > 0 && !rlang::is_named(changes)) {
        cli::cli_abort("Every metadata field in {.arg ...} must be named.")
    }
    new_c4e_tbl(.x, modify_meta(c4e_meta(.x), changes))
}

# ==== Merging metadata ==================================================== ----

#' Combine the metadata of two tables
#'
#' Single-valued fields are kept when they agree (or one side is unset) and
#' cleared when they differ; set fields are united; registries are united,
#' keeping the first definition of an indicator defined in both. With
#' `strict = TRUE` a different key is an error, a cleared field is reported
#' and a clashing indicator is a warning. `strict = FALSE` is used where
#' messages would repeat, as in vctrs type resolution.
#' @noRd
merge_meta <- function(a, b, strict = FALSE, call = rlang::caller_env()) {
    if (is.null(a)) {
        return(b)
    }
    if (is.null(b)) {
        return(a)
    }
    agree <- function(u, v) is.null(u) || is.null(v) || identical(u, v)
    out <- a

    if (agree(a$key, b$key)) {
        out["key"] <- list(a$key %||% b$key)
    } else if (strict) {
        cli::cli_abort(
            "The tables are keyed by different columns, {.field {a$key}} and
             {.field {b$key}}.",
            call = call)
    } else {
        out["key"] <- list(NULL)
    }

    cleared <- character()
    for (field in c4e_single_fields) {
        if (agree(a[[field]], b[[field]])) {
            out[field] <- list(a[[field]] %||% b[[field]])
        } else {
            out[field] <- list(NULL)
            cleared <- c(cleared, field)
        }
    }
    if (strict && length(cleared) > 0) {
        cli::cli_inform(c(
            "i" = "The tables differ in {.field {cleared}}, so the result
                   leaves {?it/them} unset.",
            "i" = "Each indicator keeps its own variable and unit."
        ))
    }

    for (field in c4e_union_fields) {
        united <- union(a[[field]], b[[field]])
        out[field] <- list(if (length(united) > 0) united)
    }
    dates <- c(a$date_range, b$date_range)
    out["date_range"] <- list(if (length(dates) > 0) range(dates))

    shared <- intersect(names(a$indicators), names(b$indicators))
    clash <- shared[!purrr::map2_lgl(a$indicators[shared], b$indicators[shared],
                                     identical)]
    if (strict && length(clash) > 0) {
        cli::cli_warn(
            "Indicator{?s} {.field {clash}} {?is/are} defined differently in
             the two tables; keeping the first definition.",
            call = call)
    }
    out$indicators <- c(a$indicators,
                        b$indicators[setdiff(names(b$indicators), names(a$indicators))])
    # pieces of one split computation share their earlier steps: keep them once
    out$history <- unique(c(a$history, b$history))
    out$schema  <- max(a$schema %||% 1L, b$schema %||% 1L)
    out
}

# ==== bind_indicators() =================================================== ----

#' Join indicator tables side by side
#'
#' Joins tables of indicators computed for the same units, for example daily
#' flags and spell lengths, into one table. Their metadata is merged: the
#' indicator registries are combined and context fields that disagree, such
#' as two different variables, are left unset in the result. Each indicator
#' keeps its own description. This replaces
#' `purrr::reduce(tables, dplyr::full_join)`, which keeps only the first
#' table's registry.
#'
#' Columns present in both tables that are not join columns and not
#' indicators, such as the `value` of the base series, are taken from the
#' first table. The same indicator column in two tables is an error.
#'
#' @param ... Data frames, or a single list of data frames.
#' @param by Optional character vector of join columns. By default, the
#'   shared columns among the key, the identifying columns, the date column,
#'   `date`, `month` and `lag`.
#'
#' @return A `c4e_tbl`.
#'
#' @export
#'
#' @examples
#' flags <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:2,
#'                  value = c(31, 32, 29), day_abv_30 = value > 30),
#'   key = "ID", date_col = "date", variable = "tmax", unit = "C"
#' )
#' spells <- tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:2,
#'                          value = c(31, 32, 29), spell_abv_30 = c(NA, 2L, NA))
#' bind_indicators(flags, spells)
bind_indicators <- function(..., by = NULL) {
    tables <- rlang::list2(...)
    if (length(tables) == 1 && is.list(tables[[1]]) &&
        !is.data.frame(tables[[1]])) {
        tables <- tables[[1]]
    }
    if (length(tables) == 0 || !all(vapply(tables, is.data.frame, logical(1)))) {
        cli::cli_abort("{.arg ...} must be data frames, or one list of them.")
    }
    call <- rlang::current_env()
    purrr::reduce(tables, \(x, y) join_indicators(x, y, by = by, call = call))
}

join_indicators <- function(x, y, by, call) {
    meta_x <- c4e_meta(x)
    meta_y <- c4e_meta(y)
    meta   <- merge_meta(meta_x, meta_y, strict = TRUE, call = call)
    shared <- intersect(names(x), names(y))

    if (is.null(by)) {
        candidates <- c(meta$key, meta$unit_cols, meta$date_col,
                        "ID", "ID_adm_div", "date", "month", "lag")
        by <- intersect(unique(candidates), shared)
    }
    if (length(by) == 0) {
        cli::cli_abort(
            "The tables share no column to join by; there is no column in
             common among the key, the identifying columns and the date.
             Give {.arg by} explicitly.",
            call = call)
    }

    registered <- union(names(meta_x$indicators), names(meta_y$indicators))
    duplicated_cols <- setdiff(shared, by)
    clash <- intersect(duplicated_cols, registered)
    if (length(clash) > 0) {
        cli::cli_abort(
            "Both tables contain the indicator{?s} {.field {clash}}. Rename or
             drop {?it/them} in one table before binding.",
            call = call)
    }

    y <- tibble::as_tibble(y)[setdiff(names(y), duplicated_cols)]
    out <- dplyr::full_join(tibble::as_tibble(x), y, by = by)
    new_c4e_tbl(out, prune_meta(meta %||% empty_meta(), names(out)), call = call)
}

# ==== S3 methods: dplyr, tibble, pillar, base ============================= ----

#' @exportS3Method dplyr::dplyr_reconstruct
dplyr_reconstruct.c4e_tbl <- function(data, template) {
    c4e_restore(NextMethod(), template)
}

# grouped data frames rebuild themselves in these two hooks without calling
# dplyr_reconstruct(), so grouped mutate() and filter() need them as well
#' @exportS3Method dplyr::dplyr_col_modify
dplyr_col_modify.c4e_tbl <- function(data, cols) {
    c4e_restore(NextMethod(), data)
}

#' @exportS3Method dplyr::dplyr_row_slice
dplyr_row_slice.c4e_tbl <- function(data, i, ...) {
    c4e_restore(NextMethod(), data)
}

#' @exportS3Method dplyr::group_by
group_by.c4e_tbl <- function(.data, ...) {
    c4e_restore(NextMethod(), .data)
}

#' @exportS3Method dplyr::ungroup
ungroup.c4e_tbl <- function(x, ...) {
    c4e_restore(NextMethod(), x)
}

#' @exportS3Method tibble::as_tibble
as_tibble.c4e_tbl <- function(x, ...) {
    attr(x, "c4e_meta") <- NULL
    class(x) <- setdiff(class(x), "c4e_tbl")
    tibble::as_tibble(x, ...)
}

#' @exportS3Method pillar::tbl_sum
tbl_sum.c4e_tbl <- function(x, ...) {
    out <- NextMethod()
    context <- describe_meta(c4e_meta(x))
    if (nzchar(context)) {
        out <- c(out, Context = context)
    }
    out
}

#' One-line summary of the metadata, for printing
#' @noRd
describe_meta <- function(meta) {
    if (is.null(meta)) {
        return("")
    }
    series <- meta$variable
    if (!is.null(meta$unit)) {
        series <- paste0(series %||% "value", " [", meta$unit, "]")
    }
    first <- paste(c(series, meta$time_step, meta$shape), collapse = ", ")
    n <- length(meta$indicators)
    parts <- c(
        if (nzchar(first)) first,
        if (!is.null(meta$key)) paste0("key ", meta$key),
        if (n > 0) paste(n, if (n == 1) "indicator" else "indicators")
    )
    paste(parts, collapse = "; ")
}

#' @export
`[.c4e_tbl` <- function(x, i, j, drop = FALSE, ...) {
    c4e_restore(NextMethod(), x)
}

#' @export
`[<-.c4e_tbl` <- function(x, i, j, ..., value) {
    c4e_restore(NextMethod(), x)
}

#' @export
`$<-.c4e_tbl` <- function(x, name, value) {
    c4e_restore(NextMethod(), x)
}

#' @export
`[[<-.c4e_tbl` <- function(x, i, j, ..., value) {
    c4e_restore(NextMethod(), x)
}

#' @export
`names<-.c4e_tbl` <- function(x, value) {
    meta <- rename_meta(c4e_meta(x), old = names(x), new = value)
    out <- NextMethod()
    # rebuild rather than set the attribute: on grouped data, dplyr's own
    # `names<-` method returns a grouped_df without the c4e_tbl class
    if (is.null(meta)) {
        return(out)
    }
    new_c4e_tbl(out, meta)
}

# ==== S3 methods: vctrs (row binding) ===================================== ----

#' @exportS3Method vctrs::vec_ptype2
vec_ptype2.c4e_tbl.c4e_tbl <- function(x, y, ...) {
    new_c4e_tbl(vctrs::tib_ptype2(x, y, ...), merge_meta(c4e_meta(x), c4e_meta(y)))
}

#' @exportS3Method vctrs::vec_ptype2
vec_ptype2.c4e_tbl.tbl_df <- function(x, y, ...) {
    new_c4e_tbl(vctrs::tib_ptype2(x, y, ...), c4e_meta(x))
}

#' @exportS3Method vctrs::vec_ptype2
vec_ptype2.tbl_df.c4e_tbl <- function(x, y, ...) {
    new_c4e_tbl(vctrs::tib_ptype2(x, y, ...), c4e_meta(y))
}

#' @exportS3Method vctrs::vec_ptype2
vec_ptype2.c4e_tbl.data.frame <- function(x, y, ...) {
    new_c4e_tbl(vctrs::tib_ptype2(x, y, ...), c4e_meta(x))
}

#' @exportS3Method vctrs::vec_ptype2
vec_ptype2.data.frame.c4e_tbl <- function(x, y, ...) {
    new_c4e_tbl(vctrs::tib_ptype2(x, y, ...), c4e_meta(y))
}

#' @exportS3Method vctrs::vec_cast
vec_cast.c4e_tbl.c4e_tbl <- function(x, to, ...) {
    new_c4e_tbl(vctrs::tib_cast(x, to, ...), c4e_meta(to))
}

#' @exportS3Method vctrs::vec_cast
vec_cast.c4e_tbl.tbl_df <- function(x, to, ...) {
    new_c4e_tbl(vctrs::tib_cast(x, to, ...), c4e_meta(to))
}

#' @exportS3Method vctrs::vec_cast
vec_cast.tbl_df.c4e_tbl <- function(x, to, ...) {
    vctrs::tib_cast(x, to, ...)
}

#' @exportS3Method vctrs::vec_cast
vec_cast.c4e_tbl.data.frame <- function(x, to, ...) {
    new_c4e_tbl(vctrs::tib_cast(x, to, ...), c4e_meta(to))
}

#' @exportS3Method vctrs::vec_cast
vec_cast.data.frame.c4e_tbl <- function(x, to, ...) {
    vctrs::df_cast(x, to, ...)
}
