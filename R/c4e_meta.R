# Helpers the step functions use to read defaults from upstream metadata,
# talk to the user, and record what they did (plan §1, §9.6, §14).

# ==== Messages ============================================================ ----

#' Is the package allowed to print messages?
#'
#' Controlled by `options(climatic4economist.verbose = FALSE)`. rlang's
#' `rlib_message_verbosity = "quiet"` also silences the messages, because they
#' are emitted with [cli::cli_inform()]. Warnings and errors are never
#' silenced.
#' @noRd
c4e_verbose <- function() {
    isTRUE(getOption("climatic4economist.verbose", TRUE))
}

#' Inform the user, unless messages are switched off
#'
#' Messages carry the class `c4e_message`, so callers can muffle them
#' selectively.
#' @noRd
c4e_inform <- function(message, ..., .envir = parent.frame()) {
    if (c4e_verbose()) {
        cli::cli_inform(message, ..., class = "c4e_message", .envir = .envir)
    }
    invisible(NULL)
}

#' Announce a step that cli marks done, with its duration, when the caller
#' returns
#' @noRd
c4e_progress_step <- function(msg, .envir = parent.frame()) {
    if (c4e_verbose()) {
        cli::cli_progress_step(msg, .envir = .envir)
    }
    invisible(NULL)
}

#' The label shown in progress messages
#'
#' `label` wins, then the label recorded in the metadata (set by the wrappers
#' from the names of a list of surveys, or by `read_climate()` from the file
#' name). `iteration` is the v1 name of `label` and is deprecated.
#' @noRd
resolve_label <- function(label = NULL, iteration = NULL, meta = NULL,
                          user_env = rlang::caller_env(2)) {
    if (!is.null(iteration)) {
        lifecycle::deprecate_soft(
            when     = "2.0.0",
            what     = I("The `iteration` argument"),
            with     = I("`label`"),
            user_env = user_env
        )
        label <- label %||% iteration
    }
    label %||% meta$label
}

# ==== Defaults from upstream ============================================== ----

#' Choose an argument's value: explicit, then upstream metadata, then default
#'
#' @param arg The argument as the user gave it, `NULL` when missing.
#' @param from The value recorded upstream, `NULL` when absent.
#' @param arg_name Name of the argument, for messages.
#' @param field Name of the metadata field `from` came from, for messages.
#' @param default Value used when neither is available.
#' @param required When `TRUE`, having no value at all is an error.
#' @noRd
c4e_default <- function(arg, from, arg_name, field = arg_name, default = NULL,
                        required = TRUE, call = rlang::caller_env()) {
    if (!is.null(arg)) {
        return(arg)
    }
    if (!is.null(from)) {
        value <- format_value(from)
        c4e_inform("Using {.code {arg_name} = {value}} from upstream {.field {field}}.")
        return(from)
    }
    if (!is.null(default)) {
        return(default)
    }
    if (!required) {
        return(NULL)
    }
    cli::cli_abort(
        c("{.arg {arg_name}} is missing, and the input carries no {.field {field}}
           to use instead.",
          "i" = "Give {.arg {arg_name}} explicitly, or build the input with a
                 climatic4economist step that records it."),
        call = call
    )
}

#' Refuse an explicit value that contradicts the metadata
#'
#' Used where silently following either side would be wrong, e.g. thresholds
#' declared in Kelvin on data in Celsius.
#' @noRd
check_meta_agrees <- function(arg, from, arg_name, field = arg_name,
                              hint = NULL, call = rlang::caller_env()) {
    if (is.null(arg) || is.null(from) ||
        isTRUE(all.equal(arg, from, check.attributes = FALSE))) {
        return(invisible(arg))
    }
    given    <- format_value(arg)
    upstream <- format_value(from)
    cli::cli_abort(
        c("{.arg {arg_name}} is {.code {given}}, but the input's {.field {field}}
           is {.code {upstream}}.",
          if (!is.null(hint)) c("i" = hint)),
        call = call
    )
}

#' Show a value the way it would be typed, e.g. `c(30, 35)` or `"C"`
#' @noRd
format_value <- function(value) {
    if (inherits(value, "Date")) {
        dates <- format_value(format(value))
        return(paste0("as.Date(", dates, ")"))
    }
    if (is.list(value)) {
        inner <- vapply(value, format_value, character(1))
        if (!is.null(names(value))) {
            inner <- ifelse(nzchar(names(value)), paste(names(value), "=", inner), inner)
        }
        return(paste0("list(", paste(inner, collapse = ", "), ")"))
    }
    paste(deparse(value, width.cutoff = 500L), collapse = " ")
}

#' A step written as code, e.g. `calc_spell(min_spell = 2L)`
#' @noRd
format_step <- function(fn, args) {
    if (length(args) == 0) {
        return(paste0(fn, "()"))
    }
    values <- vapply(args, format_value, character(1))
    paste0(fn, "(", paste(names(args), "=", values, collapse = ", "), ")")
}

# ==== History ============================================================= ----

#' Append one step to the metadata's history
#'
#' @param meta Metadata list.
#' @param fn Name of the step function.
#' @param args Named list of the arguments the step used, after defaults were
#'   resolved. `NULL` entries and values that cannot be shown as code (data,
#'   rasters, functions) are left out.
#' @param started Optional `Sys.time()` taken when the step began.
#' @noRd
c4e_record <- function(meta, fn, args = list(), started = NULL) {
    meta <- meta %||% empty_meta()
    args <- purrr::compact(args)
    args <- args[vapply(args, is_recordable, logical(1))]
    now  <- Sys.time()
    entry <- list(
        fn      = fn,
        args    = args,
        time    = now,
        elapsed = if (!is.null(started)) {
            as.numeric(difftime(now, started, units = "secs"))
        }
    )
    meta$history <- c(meta$history, list(purrr::compact(entry)))
    meta
}

is_recordable <- function(value) {
    if (is.data.frame(value) || is.function(value) || is.environment(value) ||
        isS4(value)) {
        return(FALSE)
    }
    if (is.atomic(value)) {
        return(length(value) <= 50)
    }
    is.list(value) && all(vapply(value, is_recordable, logical(1)))
}

#' Show the steps that produced a table
#'
#' Every climatic4economist step records its name and the arguments it used,
#' after defaults were filled in from upstream, along with how long it took.
#' `c4e_history()` returns that record, and printing it shows the pipeline as
#' code. Data arguments, such as the raster or the survey, are not recorded
#' and are left out of the code.
#'
#' @param x A `c4e_tbl`.
#'
#' @return A tibble of class `c4e_history` with one row per step: `step`,
#'   `call` (the step as code), `elapsed` (seconds) and `time`.
#'
#' @export
#'
#' @examples
#' x <- update_meta(tibble::tibble(ID = "1"), key = "ID")
#' c4e_history(x)
c4e_history <- function(x) {
    history <- c4e_meta(x, "history") %||% list()
    calls <- vapply(history, \(entry) format_step(entry$fn, entry$args),
                    character(1))

    out <- tibble::tibble(
        step    = seq_along(history),
        call    = calls,
        elapsed = vapply(history, \(entry) entry$elapsed %||% NA_real_, numeric(1)),
        time    = do.call(c, c(list(as.POSIXct(character(0))),
                               lapply(history, `[[`, "time")))
    )
    class(out) <- c("c4e_history", class(out))
    out
}

#' @export
print.c4e_history <- function(x, ...) {
    n <- nrow(x)
    if (n == 0) {
        cli::cat_line("<c4e history: no recorded steps>")
        return(invisible(x))
    }
    total <- sum(x$elapsed, na.rm = TRUE)
    cli::cat_line("<c4e history: ", n, if (n == 1) " step, " else " steps, ",
                  format_seconds(total), ">")

    code <- paste0(c("", rep("  ", n - 1)), x$call, c(rep(" |>", n - 1), ""))
    timing <- ifelse(is.na(x$elapsed), "", paste0("# ", format_seconds(x$elapsed)))
    width <- max(nchar(code))
    cli::cat_line(ifelse(nzchar(timing),
                         paste0(formatC(code, width = -width), "  ", timing),
                         code))
    invisible(x)
}

format_seconds <- function(seconds) {
    out <- ifelse(seconds < 60,
                  paste0(format(round(seconds, 1), nsmall = 1, trim = TRUE), " s"),
                  paste0(seconds %/% 60, " min ", round(seconds %% 60), " s"))
    unname(out)
}
