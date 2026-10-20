#' c4e: climate data for economists
#'
#' Links climate rasters to household surveys and computes weather extreme
#' indicators for the reference period before each interview. Tables carry
#' their context (variable, unit, time step, thresholds, windows) from one
#' step to the next, so a value given once is not typed again.
#'
#' c4e succeeds `climatic4economist`, which stays available unchanged for
#' existing scripts.
#'
#' @section Options:
#' * `c4e.verbose`: `FALSE` silences the package's messages,
#'   progress steps and progress bars. Warnings and errors are always shown.
#'   rlang's `rlib_message_verbosity = "quiet"` also silences the messages.
#' * `c4e.mem_limit`: memory budget for heavy steps, as bytes
#'   or a string such as `"8GB"`. Steps whose estimated size exceeds it are
#'   split by unit and run piece by piece. The default is half of the free
#'   memory.
#'
#' @author Jan Martin Rossi
#'
#' @keywords internal
#' @importFrom rlang %||%
"_PACKAGE"
