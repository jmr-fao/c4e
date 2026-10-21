# Compute the statistical mode of a vector

Returns the most frequent value in a vector, optionally handling ties in
different ways. Missing values are ignored.

## Usage

``` r
calc_mode(x, ties = c("first", "all", "NA", "error"))
```

## Arguments

- x:

  A vector.

- ties:

  Character string specifying how ties should be handled. One of:

  "first"

  :   Return the first mode encountered (default).

  "all"

  :   Return all modes.

  "NA"

  :   Return a missing value if multiple modes exist.

  "error"

  :   Throw an error if the mode is not unique.

## Value

Depending on `ties`:

- `"first"` returns a single value of the same type as `x`.

- `"all"` returns a vector containing all modal values.

- `"NA"` returns a missing value of the same type as `x` when ties
  occur.

- `"error"` returns a single value if the mode is unique, otherwise
  throws an error.

If `x` contains only missing values, a missing value of the same type as
`x` is returned.

## Details

The function is named `calc_mode()` rather than
[`mode()`](https://rdrr.io/r/base/mode.html) so that it does not mask
[`base::mode()`](https://rdrr.io/r/base/mode.html), which reports the
storage type of an object.

## Examples

``` r
calc_mode(c(1, 2, 2, 3))
#> [1] 2

calc_mode(c(1, 1, 2, 2), ties = "all")
#> [1] 1 2

calc_mode(c("a", "b", "a"))
#> [1] "a"

calc_mode(c(NA, 1, 1, 2))
#> [1] 1
```
