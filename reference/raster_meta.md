# Context recorded on a raster

Returns what
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md)
and the other package steps recorded about a raster: the variable, its
kind, the data source and a label, along with the unit and dates kept by
terra itself. The time step is inferred from the dates when it was not
recorded.

## Usage

``` r
raster_meta(x)
```

## Arguments

- x:

  A `SpatRaster`.

## Value

A list with `variable`, `unit`, `time_step`, `kind`, `source`, `label`
and `date_range`; fields that are unknown are `NULL`.

## Details

The context survives subsetting, arithmetic and cropping in memory, and
writing to and reading from a GeoTIFF. Rasters read with
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
carry it only until their first subset; read them with
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md)
to keep it throughout.

## See also

[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
raster_meta(tmax)[c("variable", "unit", "time_step")]
#> $variable
#> [1] "tmax"
#> 
#> $unit
#> [1] "K"
#> 
#> $time_step
#> [1] "day"
#> 
```
