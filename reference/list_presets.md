# List the presets of the wrappers

Presets fill the thresholds, percentiles and spell length of
[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md)
and
[`climate_indices()`](https://jmr-fao.github.io/c4e/reference/climate_indices.md)
with common definitions, so a single word replaces several numbers.
Arguments given explicitly override the preset. A preset checks that the
data are the variable and time step it expects, and converts the unit
when needed.

## Usage

``` r
list_presets()
```

## Value

A tibble with one row per preset: its name, the wrapper it belongs to,
the variable, unit and time step it expects, its specification and a
description.

## See also

[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md),
[`climate_indices()`](https://jmr-fao.github.io/c4e/reference/climate_indices.md)

## Examples

``` r
list_presets()
#> # A tibble: 10 × 7
#>    preset        wrapper          variable unit   time_step spec     description
#>    <chr>         <chr>            <chr>    <chr>  <chr>     <chr>    <chr>      
#>  1 heavy_rain    weather_extremes pre      mm/day day       above =… days with …
#>  2 wet_days_p95  weather_extremes pre      mm/day day       p = c(0… days above…
#>  3 dry_spell     weather_extremes pre      mm/day day       below =… spells of …
#>  4 dry_days_p10  weather_extremes pre      mm/day day       p = 0.1… days below…
#>  5 heat          weather_extremes tmax     C      day       above =… days with …
#>  6 heatwave_wmo  weather_extremes tmax     C      day       heatwav… WMO heatwa…
#>  7 hot_days_p90  weather_extremes tmax     C      day       p = c(0… days above…
#>  8 cold          weather_extremes tmin     C      day       below =… days with …
#>  9 cold_days_p10 weather_extremes tmin     C      day       p = c(0… days below…
#> 10 drought_spi3  climate_indices  pre      NA     month     below =… months of …
```
