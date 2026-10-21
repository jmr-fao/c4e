#' Convert a String to a Date-Like Format
#'
#' This function transforms a string by replacing underscores (`_`) and dots (`.`)
#' with hyphens (`-`) and removing a leading "X" if present. It is useful for
#' formatting column names or other identifiers into a more readable date format.
#'
#' @param x A character vector containing strings to be converted.
#'
#' @return A character vector with transformed strings.
#'
#' @noRd
#'
to_date <- function(x) {
    # anchored: a bare "X" strips the first one anywhere, so a name such as
    # "MAX_2020" would come back as "MA-2020"
    gsub("[_./]", "-", sub("^X", "", x))
}
