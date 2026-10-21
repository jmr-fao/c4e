# Heatwaves as defined by the WMO

A heatwave day is at least `excess` degrees hotter than the long-term
mean of its unit and calendar month; a heatwave is a run of at least
`min_spell` such days. Records the length of each heatwave on its last
day in `spell_wmo`. The data must be temperatures in C or K (an excess
in degrees is the same in both). Replaces `find_wmo_heatwave()` of
climatic4economist.

## Usage

``` r
calc_heatwave(
  x,
  excess = 5,
  min_spell = 2L,
  unit = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto"
)
```

## Arguments

- x:

  A wide table of daily temperatures from `extract_*()`, or a long
  indicator table.

- excess:

  Degrees above the monthly mean that make a hot day.

- min_spell:

  Minimum number of consecutive hot days.

- unit:

  Unit of the thresholds; defaults to the data's.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

A long `c4e_tbl` with the `spell_wmo` column.

## See also

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
survey <- read.csv(
  system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")

extract_by_coord(tmax, points) |> calc_heatwave(excess = 5)
#> Using `unit = "K"` from upstream unit.
#> # A tibble: 13,140 × 6
#> # Context:  tmax [K], day, long; key ID; 1 indicator
#>    ID                x_cell y_cell date       value spell_wmo
#>    <chr>              <dbl>  <dbl> <date>     <dbl>     <int>
#>  1 30.27330_-0.11150   30.3   -0.1 2021-01-01  293.        NA
#>  2 30.27330_-0.11150   30.3   -0.1 2021-01-02  295.        NA
#>  3 30.27330_-0.11150   30.3   -0.1 2021-01-03  294.        NA
#>  4 30.27330_-0.11150   30.3   -0.1 2021-01-04  292.        NA
#>  5 30.27330_-0.11150   30.3   -0.1 2021-01-05  294.        NA
#>  6 30.27330_-0.11150   30.3   -0.1 2021-01-06  292.        NA
#>  7 30.27330_-0.11150   30.3   -0.1 2021-01-07  290.        NA
#>  8 30.27330_-0.11150   30.3   -0.1 2021-01-08  292.        NA
#>  9 30.27330_-0.11150   30.3   -0.1 2021-01-09  294.        NA
#> 10 30.27330_-0.11150   30.3   -0.1 2021-01-10  294.        NA
#> # ℹ 13,130 more rows
```
