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
#' * `c4e.grid_rows`: raster rows per block in the grid functions; by
#'   default from the memory budget.
#' * `c4e.grid_fast`: `FALSE` sends sums of fixed-threshold days through
#'   the block engine instead of `terra::tapp()`; for checking.
#'
#' @author Jan Martin Rossi
#'
#' @keywords internal
#' @importFrom rlang %||% .data :=
"_PACKAGE"

utils::globalVariables(c(
    # columns named in dplyr::join_by() inequality conditions, which take
    # bare names only
    "date", "w_start", "w_end",
    # columns built inside dplyr verbs of the spatial and file helpers
    "parent", "name_var", "names_var_x", "names_var_y", "x_only", "y_only",
    "agg_road_length_km", "agg_n", "road_length_km", "n_roads", "area_km2",
    "year", "month", "n_month", "n_day", "is_leap", "flag_month", "flag_day",
    "expected_days", "src_year", "gz", "iso3_code", "shapeName", "shapeGroup",
    "shapeType", "temp_interview_col", "value", "lag"
))
