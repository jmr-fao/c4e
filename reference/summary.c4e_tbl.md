# Summarise a c4e table

Describes a `c4e_tbl`: its context, the number of units and the period
covered, each indicator with its label, share of missing values and
mean, and the checks of
[`validate_c4e()`](https://jmr-fao.github.io/c4e/reference/validate_c4e.md).

## Usage

``` r
# S3 method for class 'c4e_tbl'
summary(object, ...)
```

## Arguments

- object:

  A `c4e_tbl`.

- ...:

  Unused.

## Value

An object of class `c4e_summary`, printed as a short report.

## See also

[`validate_c4e()`](https://jmr-fao.github.io/c4e/reference/validate_c4e.md),
[`c4e_labels()`](https://jmr-fao.github.io/c4e/reference/c4e_labels.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
                 value = c(28, 31, 33, 29, 31)),
  key = "ID", date_col = "date", shape = "long", variable = "tmax",
  unit = "C", time_step = "day")
summary(calc_threshold_day(x, above = 30))
#> Using `unit = "C"` from upstream unit.
#> c4e table: tmax [C], day, long; key ID; 2 indicators
#> 5 rows, 1 units
#> 
#> Indicators:
#>   day_abv_30 flag   missing   0.0%  mean      0.6  days above 30 C
#>   C_abv_30   excess missing   0.0%  mean        1  excess above 30 C
#> 
#> Checks:
#> ✔ duplicate rows
#> ✔ empty indicators
#> ✔ units without data
#> ✔ date gaps
```
