# Convert Variable Names to Stata-Compatible Format

This function reformat a string (e.g., a date or column name) to be
compatible with Stata variable naming conventions. It substitute dashes
with underscore, remove dots and ensures that names starting with a
number are prefixed with "X" (since Stata does not allow variable names
to start with numbers).

## Usage

``` r
to_stata_format(x)
```

## Arguments

- x:

  A character vector of variable names or dates.

## Value

A character vector with modified names.

## Examples

``` r
to_stata_format("2024-01-01") # Returns "X2024_01_01"
#> [1] "X2024_01_01"
to_stata_format("var.1")      # Returns "var1"
#> [1] "var1"
to_stata_format("123_test")   # Returns "X123_test"
#> [1] "X123_test"
```
