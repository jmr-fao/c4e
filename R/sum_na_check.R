#' Sum a numeric vector while handling missing values
#'
#' This function computes the sum of a numeric vector while handling `NA`
#' values. If all values in the vector are `NA`, it returns a specified
#' replacement value.
#'
#' @param x A numeric vector.
#' @param replace A numeric value to return if all elements in `x` are `NA`.
#'   Defaults to `0`.
#'
#' @return A numeric value representing the sum of `x`, ignoring `NA` values. If
#'   all values in `x` are `NA`, it returns `replace`.
#'
#' @noRd
#'
sum_na_check <- function(x, replace = 0) {
    if (all(is.na(x))) { return(as.numeric(replace)) }
    return(as.numeric(sum(x, na.rm = TRUE)))
}
