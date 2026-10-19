#' Spells of consecutive flagged days
#'
#' For every flag column registered by an earlier step (thresholds,
#' percentiles, conditions), finds runs of consecutive flagged days and
#' records the length of each run of at least `min_spell` days on its last
#' day. `day_abv_30` gives `spell_abv_30`. Replaces [find_spell()].
#'
#' `min_spell` defaults to the one used by earlier spells of the same table,
#' announced, and otherwise to 2. A missing value ends a run.
#'
#' @param x A long table with flag columns, e.g. from
#'   [calc_threshold_day()].
#' @param min_spell Minimum number of consecutive days that make a spell.
#' @inheritParams calc_threshold_day
#'
#' @return `x` with one spell column per flag column, integer, `NA` except on
#'   the last day of each spell.
#'
#' @family indicators
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:5,
#'                  value = c(31, 32, 29, 33, 34, 35)),
#'   key = "ID", date_col = "date", shape = "long", unit = "C")
#' calc_threshold_day(x, above = 30) |> calc_spell(min_spell = 2)
calc_spell <- function(x, min_spell = NULL, id = NULL, label = NULL,
                       chunk = "auto") {
    started <- Sys.time()
    meta <- c4e_meta(x) %||% empty_meta()
    min_spell <- c4e_default(min_spell, upstream_min_spell(meta), "min_spell",
                             field = "spell", default = 2L)
    flags <- flag_columns(tibble::as_tibble(x), meta)
    if (length(flags) == 0) {
        cli::cli_abort(c(
            "{.arg x} has no flag columns to find spells in.",
            "i" = "Flag days first, e.g. with {.fn calc_threshold_day}."
        ))
    }

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        columns <- list()
        entries <- list()
        for (flag in flags) {
            spell <- spell_name(flag)
            columns[[spell]] <- run_length_rows(frame_matrix(frame, flag), min_spell)
            source <- frame$meta$indicators[[flag]] %||% list()
            entries[[spell]] <- new_indicator(
                "spell", base = flag, direction = source$direction,
                threshold = source$threshold, p = source$p,
                condition = source$condition, min_spell = min_spell,
                step = frame$meta$time_step, variable = source$variable,
                unit = source$unit)
        }
        finish_frame(frame, columns, entries)
    }

    run_indicator(x, compute, "calc_spell", args = list(min_spell = min_spell),
                  n_new = length(flags), id = id, label = label, chunk = chunk,
                  started = started)
}

#' The minimum spell length used by earlier spells, if they agree on one
#' @noRd
upstream_min_spell <- function(meta) {
    used <- unique(unlist(lapply(meta$indicators, \(entry) {
        if (identical(entry$kind, "spell")) entry$min_spell
    })))
    if (length(used) == 1) used
}

#' Percentiles of spell lengths by unit and month
#'
#' For each spell column, computes percentiles of the lengths of the spells
#' ending in each calendar month, per unit, over all years: the "unusually
#' long" spells that [calc_spell_excess()] compares with. A month without
#' any spell gets `min_spell`. Values are whole days (truncated), as in v1.
#' Replaces [calc_pct_spell()].
#'
#' Spells are computed first when `x` only has flags.
#'
#' @param x A long table with spell columns (from [calc_spell()]) or flag
#'   columns.
#' @param p Probabilities, e.g. `c(0.5, 0.9)`.
#' @inheritParams calc_spell
#'
#' @return A `c4e_tbl` lookup table: the unit identifiers, `month` and one
#'   column per spell and percentile, e.g. `spell_abv_30_90p`.
#'
#' @family indicators
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:9,
#'                  value = c(31, 32, 29, 33, 34, 35, 28, 31, 32, 33)),
#'   key = "ID", date_col = "date", shape = "long", unit = "C")
#' calc_threshold_day(x, above = 30) |>
#'   calc_spell() |>
#'   calc_spell_percentile(p = 0.9)
calc_spell_percentile <- function(x, p, min_spell = NULL, id = NULL,
                                  label = NULL, chunk = "auto") {
    started <- Sys.time()
    meta <- c4e_meta(x) %||% empty_meta()
    min_spell <- c4e_default(min_spell, upstream_min_spell(meta), "min_spell",
                             field = "spell", default = 2L)
    if (length(spell_columns(tibble::as_tibble(x), meta)) == 0) {
        x <- calc_spell(x, min_spell = min_spell, id = id)
        meta <- c4e_meta(x)
    }
    spells <- spell_columns(tibble::as_tibble(x), meta)

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        out <- NULL
        entries <- list()
        for (spell in spells) {
            pct <- quantile_by_month(frame_matrix(frame, spell), frame$dates, p,
                                     replace = min_spell)
            months <- colnames(pct[[1]])
            if (is.null(out)) {
                out <- frame$ids[rep(seq_len(nrow(frame$ids)), each = length(months)), ,
                                 drop = FALSE]
                out$month <- rep(months, times = nrow(frame$ids))
            }
            source <- frame$meta$indicators[[spell]] %||% list()
            for (j in seq_along(p)) {
                col <- paste0(spell, "_", names(pct)[j])
                out[[col]] <- as.integer(as.vector(t(pct[[j]])))
                entries[[col]] <- new_indicator(
                    "pct", base = spell, p = p[j], period = "month",
                    min_spell = min_spell, direction = source$direction,
                    threshold = source$threshold, step = frame$meta$time_step)
            }
        }
        meta <- modify_meta(frame$meta, list(
            shape = "lookup", date_col = NULL, date_range = range(frame$dates),
            indicators = entries))
        new_c4e_tbl(out, prune_meta(meta, names(out)))
    }

    run_indicator(x, compute, "calc_spell_percentile",
                  args = list(p = p, min_spell = min_spell),
                  n_new = length(spells) * length(p), id = id, label = label,
                  chunk = chunk, started = started)
}

#' Spells longer than usual
#'
#' Compares each spell with the spell-length percentiles of its unit and
#' month from [calc_spell_percentile()], and records by how many days it
#' exceeds them (`NA` for shorter spells and for days that end no spell).
#' Each percentile column is matched with the spell it was computed from
#' through the registry. Replaces [find_extr_spell_rel()].
#'
#' @param x A long table with spell columns, from [calc_spell()].
#' @param pct A spell-percentile table from [calc_spell_percentile()].
#' @inheritParams calc_spell
#'
#' @return `x` with one column per percentile, named like it, e.g.
#'   `spell_abv_30_90p`.
#'
#' @family indicators
#' @export
#'
#' @examples
#' x <- update_meta(
#'   tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:9,
#'                  value = c(31, 32, 29, 33, 34, 35, 28, 31, 32, 33)),
#'   key = "ID", date_col = "date", shape = "long", unit = "C")
#' spells <- calc_threshold_day(x, above = 30) |> calc_spell()
#' calc_spell_excess(spells, calc_spell_percentile(spells, p = 0.5))
calc_spell_excess <- function(x, pct, id = NULL, label = NULL, chunk = "auto") {
    started <- Sys.time()
    pct_meta <- c4e_meta(pct) %||% empty_meta()
    spells <- spell_columns(tibble::as_tibble(x), c4e_meta(x) %||% empty_meta())
    columns <- grep("^spell_.+_[0-9.]+p$", names(pct), value = TRUE)
    base_of <- vapply(columns, \(col) {
        pct_meta$indicators[[col]]$base %||% sub("_[0-9.]+p$", "", col)
    }, character(1))
    paired <- columns[base_of %in% spells]
    if (length(paired) == 0) {
        cli::cli_abort(c(
            "No spell percentile in {.arg pct} matches a spell in {.arg x}.",
            "i" = "Compute both from the same flags: {.fn calc_spell}, then
                   {.fn calc_spell_percentile}."
        ))
    }
    id_like <- unique(c(pct_meta$key, pct_meta$unit_cols, "month",
                        names(pct)[!vapply(pct, is.numeric, logical(1))]))
    table <- tibble::as_tibble(pct)[intersect(c(id_like, paired), names(pct))]

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        by <- intersect(frame$id_cols, names(table))
        months <- sort(unique(table$month))
        columns <- list()
        entries <- list()
        for (col in paired) {
            by_month <- matrix(NA_real_, nrow(frame$ids), length(months),
                               dimnames = list(NULL, months))
            for (m in months) {
                rows <- vctrs::vec_match(vctrs::vec_cbind(frame$ids[by], month = m),
                                         table[c(by, "month")])
                by_month[, m] <- table[[col]][rows]
            }
            threshold <- lookup_by_month(by_month, frame$dates)
            spell <- frame_matrix(frame, base_of[[col]])
            excess <- spell - threshold
            excess[is.na(spell) | spell < threshold] <- NA
            storage.mode(excess) <- "integer"
            columns[[col]] <- excess
            entries[[col]] <- new_indicator(
                "excess", base = base_of[[col]], threshold = col,
                p = pct_meta$indicators[[col]]$p,
                unit = paste0(frame$meta$time_step %||% "day", "s"))
        }
        finish_frame(frame, columns, entries)
    }

    run_indicator(x, compute, "calc_spell_excess", args = list(),
                  n_new = length(paired), id = id, label = label, chunk = chunk,
                  started = started)
}

#' Heatwaves as defined by the WMO
#'
#' A heatwave day is at least `excess` degrees hotter than the long-term
#' mean of its unit and calendar month; a heatwave is a run of at least
#' `min_spell` such days. Records the length of each heatwave on its last
#' day in `spell_wmo`. The data must be temperatures in C or K (an excess in
#' degrees is the same in both). Replaces [find_wmo_heatwave()].
#'
#' @param x A wide table of daily temperatures from `extract_*()`, or a long
#'   indicator table.
#' @param excess Degrees above the monthly mean that make a hot day.
#' @param min_spell Minimum number of consecutive hot days.
#' @inheritParams calc_threshold_day
#'
#' @return A long `c4e_tbl` with the `spell_wmo` column.
#'
#' @family indicators
#' @export
#'
#' @examples
#' tmax <- read_climate(
#'   system.file("extdata", "tmax_daily.tif", package = "climatic4economist"))
#' survey <- read.csv(
#'   system.file("extdata", "survey.csv", package = "climatic4economist"))
#' coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
#' points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
#'
#' extract_by_coord(tmax, points) |> calc_heatwave(excess = 5)
calc_heatwave <- function(x, excess = 5, min_spell = 2L, unit = NULL, id = NULL,
                          label = NULL, chunk = "auto") {
    started <- Sys.time()
    meta <- c4e_meta(x) %||% empty_meta()
    unit <- canonical_unit(resolve_unit(unit, meta))
    if (!isTRUE(unit %in% c("C", "K"))) {
        shown <- unit %||% "unknown"
        cli::cli_abort(c(
            "{.fn calc_heatwave} needs temperatures in C or K; the input's unit
             is {.val {shown}}.",
            "i" = "Give {.arg unit} if the data are temperatures without a
                   recorded unit."
        ))
    }

    compute <- function(piece) {
        frame <- indicator_frame(piece, id)
        values <- frame_matrix(frame, "value")
        months <- month_label(frame$dates)
        labels <- sort(unique(months))
        means <- vapply(labels, \(m) rowMeans(values[, months == m, drop = FALSE]),
                        numeric(nrow(values)))
        means <- matrix(means, nrow(values), length(labels),
                        dimnames = list(NULL, labels))
        hot <- (values - lookup_by_month(means, frame$dates)) >= excess
        columns <- list(spell_wmo = run_length_rows(hot, min_spell))
        entries <- list(spell_wmo = new_indicator(
            "spell", direction = "above", threshold = excess,
            definition = "wmo", min_spell = min_spell, unit = unit,
            variable = frame$meta$variable, step = frame$meta$time_step))
        finish_frame(frame, columns, entries)
    }

    run_indicator(x, compute, "calc_heatwave",
                  args = list(excess = excess, min_spell = min_spell),
                  n_new = 1, id = id, label = label, chunk = chunk,
                  started = started)
}
