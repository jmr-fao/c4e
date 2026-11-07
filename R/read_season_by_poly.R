# Growing-season bounds per administrative division, for window_calendar().
#
# The points version attaches a season to a household. This one attaches it to
# a division, which is what an analysis keyed by division needs, and has to
# decide two things the points version never faces: which statistic summarises
# a division's cells, and what to do where the cropland mask is empty.

#' Growing-season bounds for each administrative division
#'
#' Summarises a published crop calendar over the cells of each division, so a
#' division-level analysis can use a growing season as its window. The points
#' equivalent is [read_season()].
#'
#' Two choices arise that never arise for a point, and both are recorded in
#' the result rather than hidden:
#'
#' **Which statistic.** A division spans many cells and rarely one calendar.
#' `stat` takes `"mode"`, `"mean"` or both, giving `sos_mode`, `sos_mean` and
#' so on. The mode is the usual choice: it answers "when does this division
#' mostly sow", and a handful of cells on another system does not move it. The
#' mean is reported alongside because a wide gap between the two is itself the
#' finding that a division has no single season.
#'
#' **Which land cover.** ASIS masks its phenology to cropland (`"cropland"`)
#' or pasture (`"pasture"`). Give both, the default, and cropland governs
#' wherever it covers at least `min_share` of a division's cells, with pasture
#' taking over where it does not. That matters in pastoral areas, where the
#' cropland mask is empty over much of the territory: without the fallback
#' those divisions get no window and drop out of the analysis, which is
#' selection on exactly the thing being studied. `season_source` records which
#' cover each division ended up on, and `cropland_share` and `pasture_share`
#' are both reported, so the choice can be audited or overridden.
#'
#' ASIS defines the end of season with a different NDVI threshold on cropland
#' than elsewhere, so `eos` from the two covers is not strictly the same
#' quantity; `sos` is less affected. Read `season_source` before comparing
#' season *lengths* across divisions.
#'
#' Bounds are dekads, signed and linear from 1 January: a second season
#' reaching into the next year is 40, not 4, and one starting in the previous
#' year is negative. Pass `unit = "dekad"` to [window_calendar()].
#'
#' @param boundaries A `SpatVector` of divisions, from [read_boundaries()].
#' @param source Only `"asis"`. GAEZ publishes no land-cover mask and no
#'   second season, so it has nothing to summarise per division that
#'   [read_season()] does not already give per point.
#' @param season `1` or `2`.
#' @param land_cover `"cropland"`, `"pasture"`, or both for cropland with
#'   pasture where cropland is absent.
#' @param stat `"mode"`, `"mean"` or both.
#' @param min_share The share of a division's cells that must carry a cropland
#'   season before cropland governs it. Below this the division falls back to
#'   pasture, when pasture is offered.
#' @param id Name of the division column in `boundaries`; `ID_adm_div` by
#'   default.
#' @param path The dataset folder, if it is not in the spatial repository
#'   found by [find_nested_folder()].
#'
#' @return A tibble with one row per division: the division id, the requested
#'   bounds, `season_share` (the share of the division's cells carrying the
#'   season it was given), `cropland_share`, `pasture_share` and
#'   `season_source`. The unit is in the `"season_unit"` attribute.
#'
#' @seealso [read_season()], [window_calendar()]
#' @export
#'
#' @examples
#' \dontrun{
#' divisions <- read_boundaries(path, iso = "NER", level = 2)
#' seasons <- read_season_by_poly(divisions, season = 1)
#' table(seasons$season_source)
#' }
read_season_by_poly <- function(boundaries, source = "asis", season = 1,
                                land_cover = c("cropland", "pasture"),
                                stat = c("mode", "mean"), min_share = 0.1,
                                id = NULL, path = NULL) {
    source <- rlang::arg_match(source, "asis")
    stat <- rlang::arg_match(stat, c("mode", "mean"), multiple = TRUE)
    land_cover <- rlang::arg_match(land_cover, c("cropland", "pasture"),
                                   multiple = TRUE)
    if (!season %in% c(1, 2)) {
        cli::cli_abort("{.arg season} must be 1 or 2.")
    }
    if (!inherits(boundaries, "SpatVector")) {
        cli::cli_abort("{.arg boundaries} must be a {.cls SpatVector}; see
                        {.fn read_boundaries}.")
    }
    if (!is.numeric(min_share) || length(min_share) != 1 ||
        min_share < 0 || min_share > 1) {
        cli::cli_abort("{.arg min_share} must be one number between 0 and 1.")
    }

    key <- id %||% "ID_adm_div"
    ids <- if (key %in% names(boundaries)) {
        as.character(terra::values(boundaries)[[key]])
    } else {
        as.character(seq_len(nrow(boundaries)))
    }

    covers <- lapply(stats::setNames(land_cover, land_cover), function(lc) {
        season_by_division(boundaries, ids, season, lc, stat, path, key)
    })

    out <- resolve_cover(covers, land_cover, min_share, key, stat)
    attr(out, "season_unit") <- "dekad"

    given <- sum(!is.na(out[[paste0("sos_", stat[[1]])]]))
    c4e_inform("Season bounds for {given} of {nrow(out)} division{?s}, in
                dekads; pass {.code unit = \"dekad\"} to
                {.fn window_calendar}.")
    out
}

#' One land cover summarised over the divisions
#' @noRd
season_by_division <- function(boundaries, ids, season, land_cover, stat,
                               path, key) {
    files <- season_files("asis", season, land_cover, path)
    stages <- names(files)

    pulled <- lapply(stats::setNames(stages, stages), function(stage) {
        r <- terra::rast(files[[stage]])
        cells <- terra::extract(r, boundaries, ID = TRUE)
        values <- cells[[2]]
        # 251 no season, 252 error, 253 insufficient, 254 outside the mask,
        # 255 water, -9999 no data: none of them is a dekad.
        values[values >= 251 | values <= -9999] <- NA_real_
        split(values, factor(cells$ID, levels = seq_along(ids)))
    })

    summarise_one <- function(parts, fn) {
        vapply(parts, function(v) {
            v <- v[!is.na(v)]
            if (length(v) == 0) NA_real_ else as.numeric(fn(v))
        }, numeric(1), USE.NAMES = FALSE)
    }

    out <- tibble::tibble(!!key := ids)
    for (stage in stages) {
        for (s in stat) {
            fn <- if (identical(s, "mode")) calc_mode else mean
            out[[paste0(stage, "_", s)]] <- summarise_one(pulled[[stage]], fn)
        }
    }
    ## How much of each division carries a season at all: what the fallback
    ## decides on, and what makes a thinly covered division visible.
    out$share <- vapply(pulled[["sos"]],
                        function(v) if (length(v) == 0) 0 else mean(!is.na(v)),
                        numeric(1), USE.NAMES = FALSE)
    out
}

#' Cropland where it reaches min_share, pasture where it does not
#' @noRd
resolve_cover <- function(covers, land_cover, min_share, key, stat) {
    primary <- covers[[land_cover[[1]]]]
    value_cols <- setdiff(names(primary), c(key, "share"))

    shares <- tibble::tibble(
        cropland_share = covers$cropland$share %||% rep(NA_real_, nrow(primary)),
        pasture_share  = covers$pasture$share %||% rep(NA_real_, nrow(primary))
    )

    if (length(land_cover) == 1) {
        out <- primary[c(key, value_cols)]
        out$season_share <- primary$share
        out$season_source <- dplyr::if_else(primary$share > 0,
                                            land_cover[[1]], NA_character_)
        return(dplyr::bind_cols(out, shares))
    }

    fallback <- covers[[land_cover[[2]]]]
    use_primary <- primary$share >= min_share & primary$share > 0

    out <- tibble::tibble(!!key := primary[[key]])
    for (col in value_cols) {
        out[[col]] <- dplyr::if_else(use_primary, primary[[col]], fallback[[col]])
    }
    out$season_share <- dplyr::if_else(use_primary, primary$share, fallback$share)
    out$season_source <- dplyr::case_when(
        use_primary ~ land_cover[[1]],
        fallback$share > 0 ~ land_cover[[2]],
        .default = NA_character_
    )
    ## A division with neither cover carries no season, not a borrowed one.
    empty <- is.na(out$season_source)
    for (col in value_cols) {
        out[[col]][empty] <- NA_real_
    }
    out$season_share[empty] <- 0
    dplyr::bind_cols(out, shares)
}
