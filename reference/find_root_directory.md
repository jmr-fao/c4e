# Find a Root Directory by Walking Upward

Starting from a given path (default: current working directory), this
function walks up the directory tree until it finds a folder matching
one of the specified names.

## Usage

``` r
find_root_directory(start = getwd(), root_directories, ignore_case = TRUE)
```

## Arguments

- start:

  Character. Starting path (default = current working directory).

- root_directories:

  Character vector. Names of folders to match (case-insensitive by
  default).

- ignore_case:

  Logical. If TRUE, the search is case-insensitive (default = TRUE).

## Value

Character path to the found root directory, or `NULL` if not found.

## Examples

``` r
root <- file.path(tempdir(), "c4e_example")
dir.create(file.path(root, "a", "b"), recursive = TRUE, showWarnings = FALSE)

find_root_directory(start = file.path(root, "a", "b"),
                    root_directories = "c4e_example")
#> [1] "/tmp/RtmptucqwD/c4e_example"
```
