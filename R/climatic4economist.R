#' climatic4economist Package
#'
#' Contains functions for extracting weather data based on survey location and
#' to construct weather extreme indicators
#'
#' @section Options:
#' * `climatic4economist.verbose`: `FALSE` silences the package's messages,
#'   progress steps and progress bars. Warnings and errors are always shown.
#'   rlang's `rlib_message_verbosity = "quiet"` also silences the messages.
#' * `climatic4economist.mem_limit`: memory budget for heavy steps, as bytes
#'   or a string such as `"8GB"`. Steps whose estimated size exceeds it are
#'   split by unit and run piece by piece. The default is half of the free
#'   memory.
#'
#' @author Jan Martin Rossi
#'
#' @name climatic4economist
#' @importFrom rlang %||%
"_PACKAGE"
