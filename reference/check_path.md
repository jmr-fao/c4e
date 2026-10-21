# Build and validate a file path

Wrapper around
[`base::file.path()`](https://rdrr.io/r/base/file.path.html) that
progressively checks whether each component of the path exists. If the
full path does not exist, the function identifies the first missing
element and optionally lists the contents of the last valid directory.

## Usage

``` r
check_path(..., list_contents = TRUE)
```

## Arguments

- ...:

  Character vectors containing path components passed to
  [`base::file.path()`](https://rdrr.io/r/base/file.path.html).

- list_contents:

  Logical. If `TRUE` (default), list the contents of the last existing
  directory when validation fails.

## Value

A character string containing the validated file path.

## Details

The function progressively checks each level of the constructed path:


    folder/
    folder/subfolder/
    folder/subfolder/file.txt

If one level does not exist, the function stops and reports:

- the first missing path component

- the last valid directory

- optionally, the files and folders available there

This is useful for debugging typos or incorrect file structures.

## Examples

``` r
root <- file.path(tempdir(), "project")
dir.create(file.path(root, "data"), recursive = TRUE, showWarnings = FALSE)

check_path(root, "data")
#> [1] "/tmp/Rtmp3DZbaj/project/data"

# a missing part is named, with the contents of the last folder found
try(check_path(root, "dta"))
#> Error : Path does not exist.
#> Problem occurred at:
#>   /tmp/Rtmp3DZbaj/project/dta
#> 
#> Last existing directory:
#>   /tmp/Rtmp3DZbaj/project
#> 
#> Available files and folders:
#>   .
#>   ..
#>   data
```
