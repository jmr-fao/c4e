#' Find a Subfolder Within a Root Directory
#'
#' Searches for a subfolder with a given name starting from a specified root
#' directory. The function first locates the root directory using
#' `c4e::find_root_directory()` and then recursively searches
#' for the target subfolder using
#' `c4e::find_subfolder()`.
#'
#' @param folder_name A character string giving the name of the subfolder to
#'   search for.
#' @param root A character string specifying the name of the root directory
#'   from which the search should begin. Defaults to `"Users"`.
#'
#' @return
#' A character string containing the full path to the first matching sub folder.
#' The function returns `NULL` (or the value returned by
#' `c4e::find_subfolder()`) if no matching folder is found.
#'
#' @examples
#' root <- file.path(tempdir(), "c4e_example")
#' dir.create(file.path(root, "data", "weather"), recursive = TRUE,
#'            showWarnings = FALSE)
#'
#' # from a working directory inside root, find "weather" below it
#' old <- setwd(file.path(root, "data"))
#' find_folder("weather", root = "c4e_example")
#' setwd(old)
#'
#' @export

find_folder <- function(folder_name, root = "Users") {
    find_root_directory(
        root_directories = root
    ) |>
        find_subfolder(
            target = folder_name
        )
}

