# Growing-season bounds at survey locations, for window_calendar().
#
# Both sources are static climatologies rather than year-by-year retrievals,
# which is what makes them usable as an analysis window: a window that moved
# with the weather would be partly endogenous to the shock being measured.

#' Growing-season bounds at each survey location
#'
#' Attaches a start and end of season to a survey, ready for
#' [window_calendar()]. The bounds come from a published crop calendar in the
#' spatial repository rather than from the survey, so nothing has to be
#' prepared by hand.
#'
#' Two sources, both long-run averages and so fixed from year to year:
#'
#' * `"asis"`: FAO ASIS crop and pasture phenology, 1 km, derived from each
#'   pixel's long-term average NDVI profile. Carries a **second season**
#'   (`season = 2`), and is masked to cropland or pasture, so locations
#'   outside the mask come back missing. Bounds are in **dekads**, so pass
#'   `unit = "dekad"` to [window_calendar()].
#' * `"gaez"`: the GAEZ v5 agro-climatic growing period, about 9 km, from a
#'   water balance on long-run climate normals. Crop-neutral and unmasked,
#'   so it covers locations ASIS leaves out, but it publishes only the
#'   longest component of the growing period and so has no second season.
#'   Bounds are in **days**, the default `unit = "doy"`.
#'
#' Values outside the valid range are returned as `NA`: for ASIS the flags
#' for no season, error, insufficient data, no cropland and water, and for
#' GAEZ a growing period of zero days. Use the two together when coverage
#' matters, taking GAEZ where ASIS is missing.
#'
#' @param survey A data frame with coordinate columns.
#' @param source `"asis"` or `"gaez"`, see above.
#' @param season `1` or `2`. Only ASIS has a second season.
#' @param land_cover For ASIS, `"cropland"` or `"pasture"`.
#' @param lat,lon <[`tidy-select`][dplyr::dplyr_tidy_select]> Coordinate
#'   columns; `lat` and `lon` by default.
#' @param path The dataset folder, if it is not in the spatial repository
#'   found by [find_nested_folder()].
#'
#' @return `survey` with `sos` and `eos` columns added, and `mos` for ASIS.
#'   The unit is stored in the `"season_unit"` attribute.
#'
#' @seealso [window_calendar()]
#' @export
#'
#' @examples
#' \dontrun{
#' survey |>
#'     read_season("asis", season = 1) |>
#'     weather_extremes(pre, window = window_calendar(sos, eos, unit = "dekad"))
#' }
read_season <- function(survey, source = c("asis", "gaez"), season = 1,
                        land_cover = c("cropland", "pasture"),
                        lat = lat, lon = lon, path = NULL) {
    source <- rlang::arg_match(source)
    land_cover <- rlang::arg_match(land_cover)
    if (!season %in% c(1, 2)) {
        cli::cli_abort("{.arg season} must be 1 or 2.")
    }
    if (identical(source, "gaez") && season == 2) {
        cli::cli_abort(c(
            "GAEZ v5 publishes only the longest component of the growing
             period, so it has no second season.",
            i = "Use {.code source = \"asis\"} for a second season."))
    }
    lat_name <- rlang::as_name(rlang::enquo(lat))
    lon_name <- rlang::as_name(rlang::enquo(lon))
    data <- tibble::as_tibble(survey)
    missing <- setdiff(c(lat_name, lon_name), names(data))
    if (length(missing)) {
        cli::cli_abort("The survey has no {.field {missing}} column{?s}.")
    }

    files <- season_files(source, season, land_cover, path)
    rasters <- lapply(files, terra::rast)

    ok <- !is.na(data[[lat_name]]) & !is.na(data[[lon_name]])
    points <- terra::vect(as.data.frame(data[ok, c(lon_name, lat_name)]),
                          geom = c(lon_name, lat_name), crs = "EPSG:4326")
    pull <- function(r) {
        out <- rep(NA_real_, nrow(data))
        out[ok] <- as.numeric(terra::extract(r, points, ID = FALSE)[[1]])
        out
    }
    values <- lapply(rasters, pull)

    if (identical(source, "asis")) {
        # 251 no season, 252 error, 253 insufficient, 254 outside the mask,
        # 255 water, -9999 no data
        drop_flags <- function(x) dplyr::if_else(x >= 251 | x <= -9999, NA_real_, x)
        out <- data
        out$sos <- drop_flags(values$sos)
        out$mos <- drop_flags(values$mos)
        out$eos <- drop_flags(values$eos)
        unit <- "dekad"
    } else {
        start <- values$lgb
        length_days <- values$ld1
        # a zero-length growing period is desert, not a season
        empty <- is.na(start) | is.na(length_days) | length_days <= 0
        out <- data
        out$sos <- dplyr::if_else(empty, NA_real_, start)
        out$eos <- dplyr::if_else(empty, NA_real_, start + length_days)
        unit <- "doy"
    }

    found <- sum(!is.na(out$sos))
    c4e_inform("Season bounds for {found} of {nrow(out)} location{?s}, in
                {unit}{?s}; pass {.code unit = \"{unit}\"} to
                {.fn window_calendar}.")
    attr(out, "season_unit") <- unit
    out
}

#' The rasters each source needs, as a named list of paths
#' @noRd
season_files <- function(source, season, land_cover, path) {
    root <- path %||% file.path(find_nested_folder("01_spatial_repository"),
                                "geophysical", "agro_ecological")
    files <- if (identical(source, "asis")) {
        lct <- if (identical(land_cover, "cropland")) "LC-C" else "LC-G"
        stages <- c(sos = "SOS", mos = "MOS", eos = "EOS")
        stats::setNames(
            file.path(root, "FAO_ASIS", "PHE", "global",
                      sprintf("DATA_ASIS_MAPSET_PHE_ASIS.PHE.GS%d.%s.%s.tif",
                              season, stages, lct)),
            names(stages))
    } else {
        mapsets <- c(lgb = "RES01-LGB", ld1 = "RES01-LD1")
        stats::setNames(
            file.path(root, "GAEZv5", mapsets, "global",
                      sprintf("GAEZ-V5.%s.HP0120.AGERA5.HIST.tif", mapsets)),
            names(mapsets))
    }
    gone <- files[!file.exists(files)]
    if (length(gone)) {
        cli::cli_abort(c(
            "Cannot find the {source} season raster{?s}.",
            stats::setNames(unname(gone), rep("*", length(gone))),
            i = "Give {.arg path} if the dataset sits elsewhere."))
    }
    files
}
