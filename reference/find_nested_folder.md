# Find a Nested Subfolder

Recursively locates a sequence of nested folders. The search begins by
locating the first folder from a specified root directory using
[`find_folder()`](https://jmr-fao.github.io/c4e/reference/find_folder.md).
Each subsequent folder is then searched recursively within the
previously located folder using
[`c4e::find_subfolder()`](https://jmr-fao.github.io/c4e/reference/find_subfolder.md).

## Usage

``` r
find_nested_folder(..., root = "Users")
```

## Arguments

- ...:

  Character strings giving the ordered sequence of folder names to
  locate. The first folder is searched for from `root`; each subsequent
  folder is searched for within the previously located folder.

- root:

  A character string specifying the name of the root directory from
  which the search begins. Defaults to `"Users"`.

## Value

A character string containing the full path to the final folder in the
sequence.

## Details

This hierarchical search reduces the risk of matching folders with the
same name elsewhere in the file system.

## Examples

``` r
root <- file.path(tempdir(), "c4e_example")
dir.create(file.path(root, "data", "raw", "rasters"), recursive = TRUE,
           showWarnings = FALSE)

old <- setwd(root)
find_nested_folder("data", "raw", "rasters", root = "c4e_example")
#> [1] "/tmp/RtmpM4F3fw/c4e_example/data/raw/rasters"
setwd(old)
```
