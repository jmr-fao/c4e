#' Hold a threshold lookup table between absolute bounds
#'
#' Raises a threshold to `min` where it falls below it, and lowers it to `max`
#' where it rises above it, leaving the rest untouched. The bound is recorded
#' on each threshold so that the flag, the excess and the label all describe
#' the threshold actually used.
#'
#' This combines a relative threshold with an absolute guardrail, which is
#' what makes one definition of an extreme travel across climates: the 95th
#' percentile of a mild month is not a hot day anywhere, and a fixed level
#' alone fires every year in the tropics and never in the highlands. Passing
#' both conditions is the same as passing the harder of the two, so a single
#' bounded threshold replaces a hand-written `day_abv_99p & day_abv_30`.
#'
#' Thresholds are lookup tables whoever produced them, so this works on a
#' table from [calc_percentile()] and equally on agro-ecological zone limits,
#' per-district thresholds or crop-specific limits supplied by the user.
#'
#' Give `min` for an upper threshold and `max` for a lower one, so that the
#' bound points the same way as the tail. The other pairing widens the
#' indicator instead of narrowing it, and is warned about. Where the bound
#' governs, the exceedance rate is no longer the nominal one; that is the
#' point of giving it.
#'
#' @param x A threshold lookup table, from [calc_percentile()] or built by
#'   the user, with registered threshold columns.
#' @param min,max Bounds in the data's unit: the threshold is held at or
#'   above `min` and at or below `max`. One number, or one for each column
#'   bounded.
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to bound;
#'   by default every registered threshold column, the whole-year ones
#'   included.
#'
#' @return `x` with the chosen columns bounded. A registered threshold also
#'   records `min_threshold` and `max_threshold` on its entry, so the label
#'   and the excess follow; a column named through `cols` that the registry
#'   does not know is bounded without one being invented for it.
#'
#' @seealso [calc_percentile()], [calc_threshold_day()]
#' @family indicators
#' @export
#'
#' @examples
#' path <- system.file("extdata", "tmax_daily.tif", package = "c4e")
#' \dontrun{
#' pct <- calc_percentile(extracted, p = c(0.95, 0.99))
#'
#' # A hot day is unusual for the place and month AND at least 25 C.
#' bound_threshold(pct, min = 25)
#' }
bound_threshold <- function(x, min = NULL, max = NULL, cols = NULL) {
    started <- Sys.time()
    if (is.null(min) && is.null(max)) {
        cli::cli_abort("Give {.arg min}, {.arg max} or both.")
    }
    meta <- c4e_meta(x) %||% empty_meta()
    chosen <- bound_columns(x, meta, {{ cols }})

    min_t <- recycle_bound(min, chosen, "min")
    max_t <- recycle_bound(max, chosen, "max")
    warn_loose_bound(min_t, max_t, chosen, meta)

    out <- tibble::as_tibble(x)
    for (j in seq_along(chosen)) {
        column <- chosen[[j]]
        if (!is.null(min_t)) {
            out[[column]] <- pmax(out[[column]], min_t[[j]])
        }
        if (!is.null(max_t)) {
            out[[column]] <- pmin(out[[column]], max_t[[j]])
        }
        ## A column the registry does not know about is still bounded, but no
        ## entry is invented for it: an entry without a kind is not a valid
        ## indicator, and nothing here can tell what kind it would be.
        entry <- meta$indicators[[column]]
        if (!is.null(entry)) {
            meta$indicators[[column]] <- c(entry, bound_fields(min_t, max_t, j))
        }
    }
    new_c4e_tbl(out, c4e_record(meta, "bound_threshold",
                                list(min = min, max = max), started))
}

#' The threshold columns to bound: those chosen, or every registered one
#' @noRd
bound_columns <- function(x, meta, cols, call = rlang::caller_env()) {
    data <- tibble::as_tibble(x)
    chosen <- names(dplyr::select(data, {{ cols }}))
    if (length(chosen) > 0) {
        return(chosen)
    }
    registered <- names(meta$indicators)[
        vapply(meta$indicators, \(e) !is.null(e$p), logical(1))]
    registered <- intersect(registered, names(data))
    if (length(registered) == 0) {
        cli::cli_abort(c(
            "{.arg x} has no registered threshold columns to bound.",
            "i" = "Name them with {.arg cols}, or produce {.arg x} with
                   {.fn calc_percentile}."), call = call)
    }
    registered
}

#' One bound per column bounded, recycled from a single number
#' @noRd
recycle_bound <- function(bound, cols, arg, call = rlang::caller_env()) {
    if (is.null(bound)) {
        return(NULL)
    }
    if (!is.numeric(bound) || anyNA(bound)) {
        cli::cli_abort("{.arg {arg}} must be a number in the data's unit.",
                       call = call)
    }
    if (length(bound) == 1L) {
        return(rep(bound, length(cols)))
    }
    if (length(bound) != length(cols)) {
        cli::cli_abort(c(
            "{.arg {arg}} must be one number, or one for each column bounded.",
            "i" = "{length(cols)} column{?s} and {length(bound)} bound{?s} given."),
            call = call)
    }
    bound
}

#' Warn when a bound is paired with the tail it loosens
#'
#' A guardrail has to point the same way as the tail: raising the threshold of
#' an upper tail, lowering that of a lower one. The other pairing widens the
#' indicator, which is almost always a slip rather than an intention. A column
#' whose tail is not recorded is left alone, since there is nothing to check
#' it against.
#' @noRd
warn_loose_bound <- function(min_t, max_t, cols, meta) {
    tail_of <- vapply(cols, function(column) {
        p <- meta$indicators[[column]]$p
        if (is.null(p)) NA else p >= 0.5
    }, logical(1))
    if (!is.null(min_t) && any(!tail_of, na.rm = TRUE)) {
        loose <- cols[!is.na(tail_of) & !tail_of]
        cli::cli_warn(c(
            "{.arg min} raises {.field {loose}}, which {?is a/are} lower
             {?tail/tails}, so it makes the indicator more common rather than
             less.",
            "i" = "Guard a lower tail with {.arg max}."))
    }
    if (!is.null(max_t) && any(tail_of, na.rm = TRUE)) {
        loose <- cols[!is.na(tail_of) & tail_of]
        cli::cli_warn(c(
            "{.arg max} lowers {.field {loose}}, which {?is an/are} upper
             {?tail/tails}, so it makes the indicator more common rather than
             less.",
            "i" = "Guard an upper tail with {.arg min}."))
    }
    invisible(NULL)
}

#' The bound of one column, for its indicator entry
#' @noRd
bound_fields <- function(min_t, max_t, j) {
    purrr::compact(list(
        min_threshold = if (!is.null(min_t)) min_t[[j]],
        max_threshold = if (!is.null(max_t)) max_t[[j]]
    ))
}
