# Standardised precipitation indices before each interview, in one call

Runs the chain from a survey and a precipitation raster to one row per
household and lag: the mean SPI (or SPEI) at each scale over the window
before the interview, and the number of months below each drought
threshold. Daily data are summed to months first. With `pet`, the SPEI
is computed from the water balance.

## Usage

``` r
climate_indices(
  survey,
  pre,
  pet = NULL,
  lat = NULL,
  lon = NULL,
  id = NULL,
  interview = NULL,
  preset = NULL,
  index = NULL,
  scale = NULL,
  below = NULL,
  above = NULL,
  window = NULL,
  boundaries = NULL,
  control = indices_control()
)
```

## Arguments

- survey:

  The survey: a data frame with coordinates, a household identifier and
  interview dates, or a table from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md);
  or a named list of them.

- pre:

  Monthly (or daily) precipitation: a file path, a `SpatRaster` or an
  extracted table.

- pet:

  Optional potential evapotranspiration, the same way; switches to the
  SPEI.

- lat, lon, id, interview:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Survey columns: coordinates (found by name when left out), household
  identifier and interview date. Not needed after
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- preset:

  Name of a preset, e.g. `"heat"` or `"wet_days_p95"`.

- index:

  `"spi"` or `"spei"`; by default SPEI when `pet` is given.

- scale:

  Accumulation scales in months; default `c(1, 3, 6)`.

- below, above:

  Thresholds on the index; default `below = c(-1, -1.5, -2)`.

- window:

  The reference window; default the month before the interview.

- boundaries:

  Optional administrative divisions: indicators are then computed per
  cell and averaged per division (area shares).

- control:

  Further options, see
  [`indices_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md).

## Value

A `c4e_tbl` with one row per household and lag.

## Details

The chain:
[`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md),
[`georef_coord()`](https://jmr-fao.github.io/c4e/reference/georef_coord.md),
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
[`aggregate_time()`](https://jmr-fao.github.io/c4e/reference/aggregate_time.md)
when daily,
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
(or cells and
[`aggregate_to_adm()`](https://jmr-fao.github.io/c4e/reference/aggregate_to_adm.md)
with `boundaries`),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md)
and
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md).

## See also

[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md),
[`list_presets()`](https://jmr-fao.github.io/c4e/reference/list_presets.md)

## Examples

``` r
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)

climate_indices(survey,
                system.file("extdata", "pre_monthly.tif", package = "c4e"),
                id = hhid, interview = interview, scale = 3)
#> Using lat as `lat`.
#> Using lon as `lon`.
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
#> Read pre_monthly: pre [mm/month], monthly, 1984-01-01 to 2023-12-01, 480 layers
#> (synthetic).
#> ℹ climate_indices: pre in mm/month, monthly, 1984-01-01 to 2023-12-01
#>   SPI at 3 months; below -1, -1.5, -2
#>   window: 1 month before the interview
#>   12 locations, 20 survey units
#> ℹ Extracting precipitation
#> ✔ Extracting precipitation [37ms]
#> 
#> ℹ Computing SPI
#> ✔ Computing SPI [205ms]
#> 
#> ℹ Summarising over the reference windows
#> Warning: 1 of 20 household windows is `NA`: less than 80% of the days have data.
#> ℹ 1 of them has no data at all (a location on cells without data, or a window
#>   outside the dates of the data).
#> ℹ Lower `min_coverage` to keep partial windows, e.g. `min_coverage = 0.5`.
#> ✔ Summarising over the reference windows [113ms]
#> 
#> # A tibble: 20 × 8
#> # Context:  pre [mm/month], month, summary; key hhid; 4 indicators
#>    hhid    lag w_start    w_end      spi_3_mean `spi3_blw_-1_sum`
#>    <chr> <int> <date>     <date>          <dbl>             <dbl>
#>  1 HH01      0 2023-07-01 2023-07-31   NA                      NA
#>  2 HH02      0 2023-02-17 2023-03-16   -1.32                    1
#>  3 HH03      0 2023-05-19 2023-06-18    0.195                   0
#>  4 HH04      0 2023-04-30 2023-05-29    0.226                   0
#>  5 HH05      0 2023-03-16 2023-04-15    0.00215                 0
#>  6 HH06      0 2023-02-06 2023-03-05   -0.487                   0
#>  7 HH07      0 2023-05-27 2023-06-26   -0.0853                  0
#>  8 HH08      0 2023-06-30 2023-07-29    0.339                   0
#>  9 HH09      0 2023-06-16 2023-07-15    0.294                   0
#> 10 HH10      0 2023-07-02 2023-08-01    0.291                   0
#> 11 HH11      0 2023-03-10 2023-04-09    0.870                   0
#> 12 HH12      0 2023-04-10 2023-05-09   -0.717                   0
#> 13 HH13      0 2023-05-11 2023-06-10   -0.306                   0
#> 14 HH14      0 2023-07-17 2023-08-16    1.29                    0
#> 15 HH15      0 2023-04-05 2023-05-04   -0.810                   0
#> 16 HH16      0 2023-05-30 2023-06-29    0.195                   0
#> 17 HH17      0 2023-03-24 2023-04-23    0.701                   0
#> 18 HH18      0 2023-02-03 2023-03-02   -0.0873                  0
#> 19 HH19      0 2023-05-06 2023-06-05    0.195                   0
#> 20 HH20      0 2023-04-05 2023-05-04    0.0422                  0
#> # ℹ 2 more variables: `spi3_blw_-1.5_sum` <dbl>, `spi3_blw_-2_sum` <dbl>
```
