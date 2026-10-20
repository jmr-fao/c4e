#' Flag days beyond thresholds
#'
#' For every unit and day, flags whether the value lies above or below each
#' threshold, and how far beyond it lies. Replaces [find_extr_abs_day()].
#'
#' Thresholds are read in the unit of the data, which comes from upstream
#' (see [read_climate()] and [convert_unit()]). A `unit` that contradicts the
#' data is refused, so 30 is never compared with Kelvin by mistake.
#'
#' A threshold is either a number, the same for every unit, or a table
#' keyed by unit (and optionally by `month`) with one column per threshold,
#' e.g. a threshold per agro-ecological zone or the percentiles of
#' [calc_percentile()].
#'
#' Flag columns are named after the time step and the threshold:
#' `day_abv_30`, `day_blw_0.1` (`hr_` for hourly data, `mo_` for monthly).
#' Excess columns are named after the unit: `C_abv_30`, `mm_blw_0.1`. Each is
#' described in the table's registry, which later steps read.
#'
#' @param x A wide table from `extract_*()`, or a long table from an earlier
#'   indicator step.
#' @param above,below Thresholds: numbers, or a table of thresholds by unit.
#' @param unit Unit of the thresholds; defaults to the data's.
#' @param id Optional name of the unit identifier column.
#' @param label Optional name shown in progress messages.
#' @param chunk `"auto"` splits the work by unit when it would not fit in
#'   memory; a whole number forces that many units per chunk; `FALSE` never
#'   splits.
#'
#' @return A long `c4e_tbl`: the unit identifiers, `date`, `value`, earlier
#'   indicator columns, and the new flag and excess columns.
#'
#' @seealso [calc_percentile_day()], [calc_spell()], [calc_condition()]
#' @family indicators
#' @param ... Further arguments of the methods; the table method takes
#'   none.
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "c4e"))
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "c4e"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' extract_by_coord(tmax[[1:60]], points) |>
#'   convert_unit("C") |>
#'   calc_threshold_day(above = c(30, 35))
calc_threshold_day <- function(x, ...) {
    UseMethod("calc_threshold_day")
}

#' @rdname calc_threshold_day
#' @export
calc_threshold_day.default <- function(x, above = NULL, below = NULL, unit = NULL,
                                       id = NULL, label = NULL, chunk = "auto", ...) {
    rlang::check_dots_empty()
    started <- Sys.time()
    if (is.null(above) && is.null(below)) {
        cli::cli_abort("Give {.arg above}, {.arg below} or both.")
    }
    meta <- c4e_meta(x) %||% empty_meta()
    unit <- resolve_unit(unit, meta)

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        values <- frame_matrix(frame, "value")
        built <- list(columns = list(), entries = list())
        for (direction in c("above", "below")) {
            thresholds <- if (direction == "above") above else below
            if (is.null(thresholds)) next
            more <- if (is.data.frame(thresholds)) {
                table_thresholds(frame, values, thresholds, direction, unit)
            } else {
                number_thresholds(frame, values, thresholds, direction, unit)
            }
            built$columns <- c(built$columns, more$columns)
            built$entries <- c(built$entries, more$entries)
        }
        finish_frame(frame, built$columns, built$entries,
                     list(unit = canonical_unit(unit) %||% frame$meta$unit))
    }

    run_indicator(x, compute, "calc_threshold_day",
                  args = list(above = if (!is.data.frame(above)) above,
                              below = if (!is.data.frame(below)) below,
                              unit = unit),
                  n_new = 2 * (length(above) + length(below)),
                  id = id, label = label, chunk = chunk, started = started)
}

#' Flag and excess columns for numeric thresholds
#' @noRd
number_thresholds <- function(frame, values, thresholds, direction, unit) {
    step <- frame$meta$time_step
    columns <- list()
    entries <- list()
    for (threshold in thresholds) {
        suffix <- paste0(direction_short(direction), "_", threshold)
        flag   <- paste0(step_prefix(step), "_", suffix)
        excess <- paste0(excess_prefix(unit), "_", suffix)
        columns[[flag]]   <- flag_threshold(values, threshold, direction)
        columns[[excess]] <- excess_threshold(values, threshold, direction)
        common <- list(base = "value", direction = direction,
                       threshold = threshold, unit = canonical_unit(unit),
                       variable = frame$meta$variable, step = step)
        entries[[flag]]   <- do.call(new_indicator, c(list("flag"), common))
        entries[[excess]] <- do.call(new_indicator, c(list("excess"), common))
    }
    list(columns = columns, entries = entries)
}

#' Flag and excess columns for thresholds from a table by unit (and month)
#'
#' @param table A data frame keyed by the unit identifier, optionally with a
#'   `month` column ("01" to "12"); every other numeric column is a
#'   threshold.
#' @param direction `"above"` or `"below"`, or a function of the column name
#'   and its registry entry returning one of them.
#' @noRd
table_thresholds <- function(frame, values, table, direction, unit,
                             call = rlang::caller_env()) {
    by <- intersect(frame$id_cols, names(table))
    if (!frame$key %in% by) {
        cli::cli_abort("The threshold table has no {.field {frame$key}} column
                        to match the units.", call = call)
    }
    table_meta <- c4e_meta(table) %||% empty_meta()
    plain <- tibble::as_tibble(table)
    columns <- setdiff(names(plain), c(by, "month"))
    columns <- columns[vapply(plain[columns], is.numeric, logical(1))]
    if (length(columns) == 0) {
        cli::cli_abort("The threshold table has no numeric threshold column.",
                       call = call)
    }
    unit_rows <- vctrs::vec_match(frame$ids[by], plain[by])
    has_month <- "month" %in% names(plain)
    months <- if (has_month) sort(unique(plain$month))
    step <- frame$meta$time_step

    out <- list(columns = list(), entries = list())
    for (col in columns) {
        source_entry <- table_meta$indicators[[col]]
        dir <- if (is.function(direction)) direction(col, source_entry) else direction
        thresholds <- if (has_month) {
            by_month <- matrix(NA_real_, nrow(frame$ids), length(months),
                               dimnames = list(NULL, months))
            for (m in months) {
                rows <- vctrs::vec_match(
                    vctrs::vec_cbind(frame$ids[by], month = m),
                    plain[c(by, "month")])
                by_month[, m] <- plain[[col]][rows]
            }
            lookup_by_month(by_month, frame$dates)
        } else {
            matrix(plain[[col]][unit_rows], nrow(frame$ids), length(frame$dates))
        }

        suffix <- paste0(direction_short(dir), "_", sub("^(day|hr|mo)_", "", col))
        flag   <- paste0(step_prefix(step), "_", suffix)
        excess <- paste0(excess_prefix(unit), "_", suffix)
        out$columns[[flag]]   <- flag_threshold(values, thresholds, dir)
        out$columns[[excess]] <- excess_threshold(values, thresholds, dir)
        common <- list(base = "value", direction = dir, threshold = col,
                       p = source_entry$p, unit = canonical_unit(unit),
                       variable = frame$meta$variable, step = step)
        out$entries[[flag]]   <- do.call(new_indicator, c(list("flag"), common))
        out$entries[[excess]] <- do.call(new_indicator, c(list("excess"), common))
    }
    out
}

#' Flag days that meet a condition
#'
#' Adds one logical column per condition, written as an expression on the
#' table's columns, for example `hot_humid = value > 30 & rh > 60` on a
#' table joined with humidity. The columns are registered as flags, so
#' [calc_spell()] and the window summaries treat them like thresholds.
#'
#' @param x A wide table from `extract_*()`, or a long indicator table.
#' @param ... Named conditions, each giving `TRUE` or `FALSE` per row.
#' @inheritParams calc_threshold_day
#'
#' @return A long `c4e_tbl` with one new column per condition.
#'
#' @family indicators
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
#'                  value = c(28, 31, 33, 29, 31)),
#'   key = "ID", date_col = "date", shape = "long", unit = "C")
#' calc_condition(x, warm = value > 30, mild = value > 27 & value <= 30)
calc_condition <- function(x, ..., id = NULL, label = NULL) {
    started <- Sys.time()
    conditions <- rlang::enquos(..., .ignore_empty = "all")
    if (length(conditions) == 0 || !rlang::is_named(conditions)) {
        cli::cli_abort("Give each condition a name, e.g. {.code hot = value > 30}.")
    }
    frame <- indicator_frame(x, id)
    data <- tibble::as_tibble(frame$data)
    step <- frame$meta$time_step
    entries <- list()
    texts <- character()

    for (name in names(conditions)) {
        flags <- rlang::eval_tidy(conditions[[name]], data)
        if (!is.logical(flags)) {
            cli::cli_abort("Condition {.field {name}} must give TRUE or FALSE for
                            each row.")
        }
        data[[name]] <- rep_len(flags, nrow(data))
        text <- paste(rlang::expr_deparse(rlang::quo_get_expr(conditions[[name]])),
                      collapse = " ")
        texts[[name]] <- text
        entries[[name]] <- new_indicator("flag", condition = text, step = step,
                                         variable = frame$meta$variable)
    }

    meta <- frame$meta
    meta$indicators[names(entries)] <- entries
    meta <- c4e_record(meta, "calc_condition", as.list(texts), started)
    new_c4e_tbl(data, meta)
}
