#' Check a table for common data problems
#'
#' Runs four checks on a `c4e_tbl` and reports them:
#'
#' * **duplicate rows**: more than one row for a unit and date;
#' * **empty indicators**: registered columns with no value at all;
#' * **units without data**: units whose series and indicators are all
#'   missing, e.g. locations outside the raster;
#' * **date gaps**: units of a long table missing dates inside their period,
#'   given the time step.
#'
#' @param x A `c4e_tbl`.
#'
#' @return A tibble of class `c4e_checks` with one row per check: `check`,
#'   `status` (`"ok"` or `"problem"`) and `detail`. Printing it lists the
#'   checks.
#'
#' @seealso [summary.c4e_tbl()]
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = c("1", "1", "2"), date = as.Date("2022-01-01") + c(0, 2, 0),
#'                  value = c(28, 31, NA)),
#'   key = "ID", date_col = "date", shape = "long", time_step = "day")
#' validate_c4e(x)
validate_c4e <- function(x) {
    meta <- c4e_meta(x) %||% empty_meta()
    data <- tibble::as_tibble(x)
    key <- meta$key %||% resolve_key(x)
    id_cols <- unique(c(key, intersect(meta$unit_cols, names(data))))
    date_col <- meta$date_col
    if (!is.null(date_col) && !date_col %in% names(data)) date_col <- NULL
    indicators <- intersect(names(meta$indicators), names(data))
    content <- c(intersect("value", names(data)), indicators)

    checks <- list()

    by_row <- c(id_cols, date_col)
    n_duplicated <- sum(duplicated(data[by_row]))
    checks$duplicate_rows <- check_result(
        "duplicate rows", n_duplicated == 0,
        paste0(n_duplicated, " row", if (n_duplicated != 1) "s", " repeat a unit",
               if (!is.null(date_col)) " and date"))

    empty <- indicators[vapply(data[indicators], \(v) all(is.na(v)), logical(1))]
    checks$empty_indicators <- check_result(
        "empty indicators", length(empty) == 0,
        if (length(empty) > 0) paste("no value in", paste(empty, collapse = ", ")))

    units_without <- character()
    if (length(content) > 0) {
        has_value <- rowSums(!is.na(as.matrix(data[content]))) > 0
        with_data <- vctrs::vec_unique(data[has_value, id_cols, drop = FALSE])
        all_units <- vctrs::vec_unique(data[id_cols])
        missing_units <- all_units[is.na(vctrs::vec_match(all_units, with_data)), , drop = FALSE]
        units_without <- as.character(missing_units[[key]])
    }
    checks$units_without_data <- check_result(
        "units without data", length(units_without) == 0,
        if (length(units_without) > 0) {
            paste0(length(units_without), " unit", if (length(units_without) != 1) "s",
                   ": ", paste(utils::head(units_without, 5), collapse = ", "),
                   if (length(units_without) > 5) ", ...")
        })

    gaps <- character()
    if (!is.null(date_col) && !is.null(meta$time_step) && meta$time_step %in% c("day", "month", "year")) {
        dates <- parse_date_label(data[[date_col]])
        per_unit <- split(dates, vctrs::vec_group_id(data[id_cols]))
        unit_keys <- vctrs::vec_unique(data[id_cols])[[key]]
        missing_dates <- vapply(per_unit, \(d) {
            d <- d[!is.na(d)]
            if (length(d) < 2) return(0)
            expected <- seq(min(d), max(d), by = meta$time_step)
            length(setdiff(expected, d))
        }, numeric(1))
        gaps <- as.character(unit_keys[missing_dates > 0])
    }
    checks$date_gaps <- check_result(
        "date gaps", length(gaps) == 0,
        if (length(gaps) > 0) {
            paste0(length(gaps), " unit", if (length(gaps) != 1) "s",
                   " miss dates inside their period: ",
                   paste(utils::head(gaps, 5), collapse = ", "),
                   if (length(gaps) > 5) ", ...")
        })

    out <- do.call(rbind, checks)
    rownames(out) <- NULL
    out <- tibble::as_tibble(out)
    class(out) <- c("c4e_checks", class(out))
    out
}

check_result <- function(check, ok, detail = NULL) {
    data.frame(check = check, status = if (ok) "ok" else "problem",
               detail = if (ok) "" else detail %||% "", stringsAsFactors = FALSE)
}

#' @export
print.c4e_checks <- function(x, ...) {
    for (i in seq_len(nrow(x))) {
        if (x$status[i] == "ok") {
            cli::cli_alert_success("{x$check[i]}")
        } else {
            cli::cli_alert_danger("{x$check[i]}: {x$detail[i]}")
        }
    }
    invisible(x)
}

#' Summarise a c4e table
#'
#' Describes a `c4e_tbl`: its context, the number of units and the period
#' covered, each indicator with its label, share of missing values and
#' mean, and the checks of [validate_c4e()].
#'
#' @param object A `c4e_tbl`.
#' @param ... Unused.
#'
#' @return An object of class `c4e_summary`, printed as a short report.
#'
#' @seealso [validate_c4e()], [c4e_labels()]
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
#'                  value = c(28, 31, 33, 29, 31)),
#'   key = "ID", date_col = "date", shape = "long", variable = "tmax",
#'   unit = "C", time_step = "day")
#' summary(calc_threshold_day(x, above = 30))
summary.c4e_tbl <- function(object, ...) {
    meta <- c4e_meta(object)
    data <- tibble::as_tibble(object)
    key <- meta$key %||% resolve_key(object)
    id_cols <- unique(c(key, intersect(meta$unit_cols, names(data))))
    id_cols <- setdiff(id_cols, "lag")
    indicators <- intersect(names(meta$indicators), names(data))
    labels <- c4e_labels(object)
    structure(
        list(
            context = describe_meta(meta),
            n_rows = nrow(data),
            n_units = nrow(vctrs::vec_unique(data[id_cols])),
            date_range = meta$date_range,
            window = if (!is.null(meta$window)) describe_window(meta$window),
            indicators = tibble::tibble(
                column  = indicators,
                kind    = vapply(meta$indicators[indicators], `[[`, "", "kind"),
                missing = vapply(data[indicators], \(v) mean(is.na(v)), numeric(1)),
                mean    = vapply(data[indicators], \(v) {
                    if (is.numeric(v) || is.logical(v)) mean(as.numeric(v), na.rm = TRUE) else NA_real_
                }, numeric(1)),
                label   = unname(labels[indicators])
            ),
            checks = validate_c4e(object)
        ),
        class = "c4e_summary"
    )
}

#' @export
print.c4e_summary <- function(x, ...) {
    cli::cli_text("{.strong c4e table}: {x$context}")
    cli::cli_text("{x$n_rows} rows, {x$n_units} units",
                  if (!is.null(x$date_range)) ", {x$date_range[1]} to {x$date_range[2]}")
    if (!is.null(x$window)) cli::cli_text("Window: {x$window}")
    if (nrow(x$indicators) > 0) {
        cli::cli_text("")
        cli::cli_text("Indicators:")
        shown <- x$indicators
        lines <- sprintf("  %-*s %-6s missing %5.1f%%  mean %s  %s",
                         max(nchar(shown$column)), shown$column, shown$kind,
                         100 * shown$missing,
                         formatC(shown$mean, format = "g", digits = 4, width = 8),
                         shown$label)
        cli::cat_line(lines)
    }
    cli::cli_text("")
    cli::cli_text("Checks:")
    print(x$checks)
    invisible(x)
}
