# Convert data to another unit

Converts a raster or a table to another unit of measure and records the
new unit, so later steps read thresholds in the right unit.

## Usage

``` r
convert_unit(x, to, from = NULL, ...)

# S3 method for class 'SpatRaster'
convert_unit(x, to, from = NULL, ...)

# S3 method for class 'c4e_tbl'
convert_unit(x, to, from = NULL, cols = NULL, ...)

# S3 method for class 'data.frame'
convert_unit(x, to, from = NULL, cols = NULL, ...)
```

## Arguments

- x:

  A `SpatRaster`, a `c4e_tbl` or a data frame.

- to:

  Unit to convert to.

- from:

  Unit to convert from. Defaults to the unit recorded in `x`.

- ...:

  Unused.

- cols:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional columns to convert instead of the base series. Indicator
  columns are still handled from the registry.

## Value

`x` in the new unit, of the same class (a `c4e_tbl` for data frames).

## Details

- On a `SpatRaster`, the unit is read from
  [`terra::units()`](https://rspatial.github.io/terra/reference/units.html)
  and written back; layer names and dates are kept.

- On a `c4e_tbl`, the unit comes from the metadata. The base series is
  converted: the date columns of a wide table, or `value` in a long one.
  Indicator columns that are amounts are converted too. Percentiles are
  levels and take the full conversion. Excesses over a threshold are
  differences, so a K to C conversion leaves them unchanged. Counts of
  days and spell lengths never change. Numeric thresholds in the
  registry are converted, so `day_abv_303.15` in K is recorded as a
  threshold of 30 C.

- On a plain data frame, `from` is required; the result is a `c4e_tbl`.

Unit names are matched loosely: `"degC"`, `"deg C"` and `"Celsius"` all
mean `"C"`, and `"kg m-2 s-1"` means `"kg/m2/s"`. Rates per unit of time
convert through their numerator: `"kg/m2/s"` to `"mm/day"` multiplies by
86400. Months and years have varying lengths, so `"mm/day"` to
`"mm/month"` multiplies each value by the days in its month and needs
monthly data.

## See also

[`register_unit()`](https://jmr-fao.github.io/c4e/reference/register_unit.md),
[`list_units()`](https://jmr-fao.github.io/c4e/reference/list_units.md)

## Examples

``` r
tmax <- terra::rast(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
terra::units(tmax)[1]
#> [1] "K"
tmax_c <- convert_unit(tmax[[1:3]], "C")
terra::units(tmax_c)[1]
#> [1] "C"

wide <- data.frame(ID = "1", X2022.01.01 = 300, X2022.01.02 = 305)
convert_unit(wide, "C", from = "K")
#> # A tibble: 1 × 3
#> # Context:  value [C], wide; key ID
#>   ID    X2022.01.01 X2022.01.02
#>   <chr>       <dbl>       <dbl>
#> 1 1            26.9        31.9
```
