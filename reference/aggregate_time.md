# Aggregate a raster to a coarser time step

Aggregates the layers of a raster by day, month or year, for example
hourly ERA5 temperature to daily maxima or daily rainfall to monthly
totals. The result's layers are named by the ISO date on which each
period starts (`"2021-02-01"` for February 2021), carry those dates, and
record the new time step.

## Usage

``` r
aggregate_time(x, to = c("day", "month", "year"), fn = NULL, ..., label = NULL)
```

## Arguments

- x:

  A `SpatRaster` with dates, ideally read with
  [`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md).

- to:

  Target time step: `"day"`, `"month"` or `"year"`.

- fn:

  Summary function name passed to
  [`terra::tapp()`](https://rspatial.github.io/terra/reference/tapp.html),
  e.g. `"sum"`, `"mean"`, `"max"`, `"min"`, `"modal"`.

- ...:

  Further arguments to
  [`terra::tapp()`](https://rspatial.github.io/terra/reference/tapp.html),
  e.g. `na.rm = TRUE`.

- label:

  Optional label for the result; defaults to that of `x`.

## Value

A `SpatRaster` with one layer per period.

## Details

When `fn` is not given it follows from the variable: amounts such as
precipitation and evapotranspiration are summed, categorical layers take
the most frequent value, everything else is averaged. The choice is
announced. Summing a rate per time step gives a rate per new period, so
daily `"mm/day"` summed to months is recorded as `"mm/month"`.

## See also

[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
[`raster_meta()`](https://jmr-fao.github.io/c4e/reference/raster_meta.md)

## Examples

``` r
pre <- read_climate(
  system.file("extdata", "pre_daily.tif", package = "c4e"))
#> Read pre_daily: pre [mm/day], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
monthly <- aggregate_time(pre[[1:59]], "month")
#> Aggregating to month with `fn = "sum"`: pre is an amount.
names(monthly)
#> [1] "2021-01-01" "2021-02-01"
```
