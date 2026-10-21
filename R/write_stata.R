#' Write a table to Stata with labelled variables
#'
#' Writes a table as a Stata `.dta` file. Every indicator gets a variable
#' label saying what it measures, built from the table's context by
#' [c4e_labels()], so the file explains itself to whoever opens it.
#'
#' Column names are made valid for Stata: a minus sign becomes `m` and a
#' decimal point `p` (`spi3_blw_-1.5` is written `spi3_blw_m1p5`), other
#' characters become `_`, and date columns get an `X` in front
#' (`X2021_01_01`). Names longer than Stata's 32 characters, or two columns
#' that would get the same name, are refused before anything is written.
#' Logical flags are written as 0/1.
#'
#' With `codebook = TRUE`, a Markdown file next to the `.dta`
#' (`<name>_codebook.md`) lists each variable with its original name and
#' label, the context of the data, and the steps that produced it
#' ([c4e_history()]).
#'
#' @param x A `c4e_tbl` or a data frame.
#' @param path Path of the `.dta` file.
#' @param labels When `TRUE`, write variable labels.
#' @param codebook When `TRUE`, also write the codebook.
#' @param version Stata file version, passed to [haven::write_dta()].
#' @param ... Further arguments to [haven::write_dta()].
#'
#' @return `path`, invisibly.
#'
#' @seealso [c4e_labels()]
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
#'                  value = c(28, 31, 33, 29, 31)),
#'   key = "ID", date_col = "date", shape = "long", variable = "tmax",
#'   unit = "C", time_step = "day")
#' hot <- calc_threshold_day(x, above = 30)
#' write_stata(hot, tempfile(fileext = ".dta"), codebook = TRUE)
write_stata <- function(x, path, labels = TRUE, codebook = FALSE, version = 14,
                        ...) {
    rlang::check_installed("haven", reason = "to write Stata files.")
    data <- tibble::as_tibble(x)
    label_of <- if (labels) c4e_labels(x) else character()

    new_names <- stata_names(names(data))
    too_long <- names(data)[nchar(new_names) > 32]
    if (length(too_long) > 0) {
        cli::cli_abort(c(
            "Stata names are at most 32 characters; {cli::qty(too_long)}{?this column
             is/these columns are} longer: {.field {too_long}}.",
            "i" = "Rename {cli::qty(too_long)}{?it/them} first, e.g. with {.fn dplyr::rename}; the
                   metadata follows the new name."
        ))
    }
    clash <- new_names[duplicated(new_names)]
    if (length(clash) > 0) {
        clashing <- names(data)[new_names %in% clash]
        cli::cli_abort("Columns {.field {clashing}} would get the same Stata name.")
    }

    for (col in names(data)) {
        if (is.logical(data[[col]])) {
            data[[col]] <- as.integer(data[[col]])
        }
        if (!is.null(label_of[col]) && !is.na(label_of[col])) {
            attr(data[[col]], "label") <- label_of[[col]]
        }
    }
    original <- names(data)
    names(data) <- new_names
    haven::write_dta(data, path, version = version, ...)

    if (codebook) {
        write_codebook(x, original, new_names, label_of, codebook_path(path))
    }
    n_rows <- nrow(data)
    n_cols <- ncol(data)
    c4e_inform("Wrote {n_rows} row{?s} and {n_cols} variable{?s} to {.file {path}}.")
    invisible(path)
}

#' Stata-valid names that keep signs and decimals: "-1.5" becomes "m1p5"
#' @noRd
stata_names <- function(x) {
    is_date <- grepl(date_pattern(), x)
    out <- x
    out[is_date] <- to_stata_format(x[is_date])
    other <- x[!is_date]
    other <- gsub("-(?=[0-9])", "m", other, perl = TRUE)
    other <- gsub("(?<=[0-9])\\.(?=[0-9])", "p", other, perl = TRUE)
    other <- gsub("[^A-Za-z0-9_]", "_", other)
    other <- sub("^([0-9])", "X\\1", other)
    out[!is_date] <- other
    out
}

codebook_path <- function(path) {
    sub("\\.dta$", "_codebook.md", path, ignore.case = TRUE)
}

#' The Markdown codebook written next to a .dta file
#' @noRd
write_codebook <- function(x, original, stata, label_of, path) {
    meta <- c4e_meta(x) %||% empty_meta()
    context <- c(
        if (!is.null(meta$variable)) paste0("- Variable: ", series_label(meta)),
        if (!is.null(meta$source)) paste0("- Source: ", meta$source),
        if (!is.null(meta$date_range)) paste0("- Dates: ", paste(meta$date_range, collapse = " to ")),
        if (!is.null(meta$crs)) paste0("- CRS: ", meta$crs),
        if (!is.null(meta$window)) paste0("- Window: ", describe_window(meta$window)),
        if (!is.null(meta$key)) paste0("- One row per: ", paste(c(meta$key, meta$unit_cols), collapse = ", ")),
        if (!is.null(meta$survey$displaced)) {
            paste0("- Coordinates: ", describe_displacement(meta$survey$displaced),
                   "; every variable computed from them uses the displaced locations")
        }
    )
    escape <- function(text) gsub("|", "\\|", text, fixed = TRUE)
    rows <- paste0("| `", stata, "` | `", original, "` | ",
                   escape(ifelse(is.na(label_of[original]), "", label_of[original])), " |")
    history <- c4e_history(x)
    steps <- if (nrow(history) > 0) {
        c("", "## Steps", "", "```r", utils::capture.output(print(history))[-1], "```")
    }
    lines <- c(
        paste0("# Codebook: ", basename(sub("_codebook\\.md$", ".dta", path))),
        "",
        paste0("Written by c4e on ", format(Sys.Date()), "."),
        if (length(context) > 0) c("", "## Data", "", context),
        "", "## Variables", "",
        "| Stata name | Column | Label |",
        "|---|---|---|",
        rows,
        steps
    )
    writeLines(lines, path)
}
