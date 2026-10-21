# Check a table for common data problems

Runs four checks on a `c4e_tbl` and reports them:

## Usage

``` r
validate_c4e(x)
```

## Arguments

- x:

  A `c4e_tbl`.

## Value

A tibble of class `c4e_checks` with one row per check: `check`, `status`
(`"ok"` or `"problem"`) and `detail`. Printing it lists the checks.

## Details

- **duplicate rows**: more than one row for a unit and date;

- **empty indicators**: registered columns with no value at all;

- **units without data**: units whose series and indicators are all
  missing, e.g. locations outside the raster;

- **date gaps**: units of a long table missing dates inside their
  period, given the time step.

## See also

[`summary.c4e_tbl()`](https://jmr-fao.github.io/c4e/reference/summary.c4e_tbl.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = c("1", "1", "2"), date = as.Date("2022-01-01") + c(0, 2, 0),
                 value = c(28, 31, NA)),
  key = "ID", date_col = "date", shape = "long", time_step = "day")
validate_c4e(x)
#> ✔ duplicate rows
#> ✔ empty indicators
#> ✖ units without data: 1 unit: 2
#> ✖ date gaps: 1 unit miss dates inside their period: 1
```
