# Find a Subfolder by Name

Recursively searches for a subfolder within a root directory up to a
given depth.

## Usage

``` r
find_subfolder(
  root,
  target,
  max_depth = 10,
  ignore_case = TRUE,
  first_only = TRUE
)
```

## Arguments

- root:

  Character. Path to the root directory to start searching from.

- target:

  Character. Substring or regex pattern to match folder names.

- max_depth:

  Integer. Maximum depth of search (default = 10).

- ignore_case:

  Logical. If TRUE, search is case-insensitive (default = TRUE).

- first_only:

  Logical. If TRUE, return only the first match (default = TRUE).

## Value

Character vector of matching folder paths. If no match is found, returns
`NULL`.

## Examples

``` r
root <- file.path(tempdir(), "c4e_example")
dir.create(file.path(root, "data", "weather"), recursive = TRUE,
           showWarnings = FALSE)

find_subfolder(root, "weather")
#> [1] "/tmp/Rtmpf0kUEo/c4e_example/data/weather"
```
