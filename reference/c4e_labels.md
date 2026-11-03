# Labels describing the columns of a table

Builds one label per column from the context the table carries: what
each indicator counts, its threshold and unit, its spell length, the
window it was summarised over. For example `day_abv_30_sum` becomes "sum
of days above 30 C, 1 year before the interview".
[`write_stata()`](https://jmr-fao.github.io/c4e/reference/write_stata.md)
writes them as Stata variable labels.

## Usage

``` r
c4e_labels(x)
```

## Arguments

- x:

  A `c4e_tbl`.

## Value

A named character vector, one label per described column, at most 80
characters (Stata's limit).

## See also

[`write_stata()`](https://jmr-fao.github.io/c4e/reference/write_stata.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
                 value = c(28, 31, 33, 29, 31)),
  key = "ID", date_col = "date", shape = "long", variable = "tmax",
  unit = "C", time_step = "day")
calc_threshold_day(x, above = 30) |> c4e_labels()
#> Using `unit = "C"` from upstream unit.
#>          day_abv_30            C_abv_30               value 
#>   "days above 30 C" "excess above 30 C"  "tmax in C, daily" 
```
