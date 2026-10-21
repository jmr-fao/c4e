#' Aggregate cell indicators to administrative divisions
#'
#' Averages cell-level indicators within each administrative division,
#' weighting each cell by the share of it inside the division
#' (`coverage_fraction` from [extract_cell_by_poly()]). Replaces
#' `agg_to_adm_div()`.
#'
#' Rows are grouped by the division and, when present, by `lag`, the date,
#' `month` or `period`. On daily flags this gives the share of the division's
#' area beyond the threshold each day; summed over a window by
#' [summarise_by_interview()], it gives area-weighted days.
#'
#' The columns averaged are the registered indicators by default.
#'
#' @param x A table of cell-level indicators with a coverage column.
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to
#'   average; by default the registered indicators.
#' @param extra_col <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns
#'   carried through; they must be constant within each division.
#' @param id Optional name of the division column; by default `ID_adm_div`.
#' @param weights Name of the weight column.
#'
#' @return A `c4e_tbl` with one row per division (and lag or date).
#'
#' @export
#'
#' @examples
#' tmax <- read_climate(system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
#'
#' extract_cell_by_poly(tmax[[1:10]], adm_div) |>
#'   calc_threshold_day(above = 300) |>
#'   aggregate_to_adm()
aggregate_to_adm <- function(x, cols = NULL, extra_col = NULL, id = NULL,
                             weights = "coverage_fraction") {
    started <- Sys.time()
    meta <- c4e_meta(x) %||% empty_meta()
    data <- tibble::as_tibble(x)
    key <- id %||% (if ("ID_adm_div" %in% names(data)) "ID_adm_div") %||%
        resolve_key(x, candidates = c("ID_adm_div", "ID"))
    if (!weights %in% names(data)) {
        cli::cli_abort("{.arg x} has no {.field {weights}} column to weight the
                        cells with.")
    }
    group <- c(key, intersect(c("lag", meta$date_col %||% "date", "month", "period"),
                              names(data)))
    extra_names <- names(dplyr::select(data, {{ extra_col }}))

    columns <- names(dplyr::select(data, {{ cols }}))
    if (length(columns) == 0) {
        columns <- intersect(names(meta$indicators), names(data))
        if (length(columns) == 0) {
            columns <- grep("^day|^spell|abv|blw", names(data), value = TRUE)
        }
    }
    columns <- setdiff(columns, c(group, weights, extra_names))
    columns <- columns[vapply(data[columns], \(v) is.numeric(v) || is.logical(v),
                              logical(1))]

    out <- data |>
        dplyr::summarise(
            dplyr::across(dplyr::all_of(extra_names), unique),
            dplyr::across(dplyr::all_of(columns),
                          \(v) stats::weighted.mean(v, w = .data[[weights]], na.rm = TRUE)),
            .by = dplyr::all_of(group)) |>
        dplyr::relocate(dplyr::all_of(extra_names), .after = dplyr::all_of(key))
    out <- sort_long(out, group)

    new_meta <- modify_meta(meta, list(
        key = key,
        unit_cols = intersect(meta$unit_cols, setdiff(group, key)),
        spatial_agg = list(level = "adm_div", fn = "weighted.mean", weights = weights)))
    new_meta$indicators <- new_meta$indicators[intersect(names(new_meta$indicators), columns)]
    new_meta <- c4e_record(new_meta, "aggregate_to_adm",
                           list(id = id, weights = weights), started)
    new_c4e_tbl(out, prune_meta(new_meta, names(out)))
}
