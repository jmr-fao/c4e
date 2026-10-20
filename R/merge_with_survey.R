#' Merge survey observations with other data.
#'
#' The two tables are matched on the column identifying the units.
#'
#' @param survey A data frame. It must contain the unit identifier column used
#'   for the merging.
#' @param id Optional character string naming the column that identifies the
#'   units. When `NULL`, `ID` is used, or `ID_adm_div` when that is the only
#'   one present.
#' @param iteration Deprecated; use `label`.
#' @param label Optional name shown in progress messages.
#' @param new_value A data frame. The data to be merge with the
#'   survey. It must carry the same identifier column as `survey`.
#'
#' @returns A \link[tibble]{tbl_df}, with variables from the survey and new
#'   weather values: a `c4e_tbl` with the context of `new_value` when it has
#'   one, recording which columns came from the survey.
#'
#' @details
#' Joining a long daily table onto a survey repeats every day for every
#' household at the location, which grows quickly; when the result would
#' exceed the memory budget a warning points to [summarise_by_interview()],
#' which summarises each household's reference period without building the
#' joined table.
#'
#' @seealso [dplyr::full_join()]
#'
#' @export
#'
#' @examples
#' tmax <- terra::rast(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#' tmax_points <- extract_by_coord(tmax[[1:5]], points)
#'
#' merge_with_survey(coord, tmax_points)

merge_with_survey <- function(survey,
                              new_value,
                              iteration = NULL,
                              id = NULL,
                              label = NULL) {
    started <- Sys.time()
    label <- resolve_label(label, iteration)
    if (!is.null(label)) {
        c4e_progress_step("Merging with survey: {label}")
    }

    key <- resolve_key(survey, id)
    if (!key %in% names(new_value)) {
        stop("Column `", key, "` not found in `new_value`. Both tables must ",
             "carry the same identifier column.", call. = FALSE)
    }
    warn_if_exploding(survey, new_value, key)

    survey_part <- tibble::as_tibble(survey) |>
        dplyr::select(-dplyr::matches(date_pattern()))
    out <- dplyr::full_join(survey_part, tibble::as_tibble(new_value), by = key,
                            relationship = "many-to-many")

    meta <- c4e_meta(new_value)
    if (is.null(meta)) {
        return(out)
    }
    survey_meta <- c4e_meta(survey) %||% empty_meta()
    meta <- modify_meta(meta, list(
        key = key,
        survey = survey_meta$survey,
        survey_cols = setdiff(names(survey_part), key),
        history = unique(c(survey_meta$history, meta$history))
    ))
    meta <- c4e_record(meta, "merge_with_survey", list(id = id), started)
    new_c4e_tbl(out, prune_meta(meta, names(out)))
}

#' Warn when joining a long table onto a survey would be very large
#'
#' Every row of `new_value` for a location is repeated for every survey row
#' at that location: a daily series of years joined to households grows to
#' households times days.
#' @noRd
warn_if_exploding <- function(survey, new_value, key, call = rlang::caller_env()) {
    per_key_survey <- table(tibble::as_tibble(survey)[[key]])
    per_key_value  <- table(tibble::as_tibble(new_value)[[key]])
    shared <- intersect(names(per_key_survey), names(per_key_value))
    n_rows <- sum(as.numeric(per_key_survey[shared]) * as.numeric(per_key_value[shared]))
    estimate <- estimate_bytes(n_rows, ncol(survey) + ncol(new_value))
    budget <- mem_budget()
    if (n_rows > nrow(survey) && estimate > budget) {
        size <- format_bytes(estimate)
        limit <- format_bytes(budget)
        cli::cli_warn(c(
            "The merged table will hold about {format(n_rows, big.mark = ',')} rows
             ({size}), more than the memory budget of {limit}.",
            "i" = "Every day is repeated for every household. To summarise days
                   over each household's reference period, use
                   {.fn summarise_by_interview} instead."
        ), call = call)
    }
    invisible(n_rows)
}
