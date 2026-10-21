# Extreme weather before each interview, in one call

Runs the whole chain from a survey and a daily climate raster to one row
per household and lag: the number of days beyond thresholds or
percentiles, the excess over them, and the spells they form, over the
window before each interview. The result's
[`c4e_history()`](https://jmr-fao.github.io/c4e/reference/c4e_history.md)
shows the equivalent step-by-step code, to copy and adapt.

## Usage

``` r
weather_extremes(
  survey,
  climate,
  lat = NULL,
  lon = NULL,
  id = NULL,
  interview = NULL,
  preset = NULL,
  above = NULL,
  below = NULL,
  p = NULL,
  spells = TRUE,
  min_spell = NULL,
  window = NULL,
  boundaries = NULL,
  baseline = NULL,
  unit = NULL,
  control = extremes_control()
)
```

## Arguments

- survey:

  The survey: a data frame with coordinates, a household identifier and
  interview dates, or a table from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md);
  or a named list of them.

- climate:

  A daily raster (file path or `SpatRaster`), or a table already
  extracted at the survey locations.

- lat, lon, id, interview:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Survey columns: coordinates (found by name when left out), household
  identifier and interview date. Not needed after
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- preset:

  Name of a preset, e.g. `"heat"` or `"wet_days_p95"`.

- above, below:

  Absolute thresholds, in the data's unit.

- p:

  Probabilities for relative thresholds, e.g. `c(0.9, 0.95)`.

- spells:

  When `TRUE`, add spells of the flagged days.

- min_spell:

  Minimum spell length in days; default 2.

- window:

  The reference window; default the year before the interview, see
  [`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md).

- boundaries:

  Optional administrative divisions: indicators are then computed per
  cell and averaged per division (area shares).

- baseline:

  Optional dates `c(from, to)` for the percentiles.

- unit:

  Unit of the thresholds, when the data's should not be used.

- control:

  Further options, see
  [`extremes_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md).

## Value

A `c4e_tbl` with one row per household and lag; with `keep_steps`, a
list of the intermediate tables; with `dry_run`, `NULL`.

## Details

The chain:
[`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md),
[`georef_coord()`](https://jmr-fao.github.io/c4e/reference/georef_coord.md),
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
(or
[`extract_cell_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_cell_by_poly.md)
and
[`aggregate_to_adm()`](https://jmr-fao.github.io/c4e/reference/aggregate_to_adm.md)
with `boundaries`),
[`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)
when needed,
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)
and/or
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
with
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md)
(or
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md)),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
and
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md).

Pick the indicators with a `preset` (see
[`list_presets()`](https://jmr-fao.github.io/c4e/reference/list_presets.md))
or with `above`, `below` and `p`; explicit arguments override the
preset. Thresholds are read in the data's unit, except that Kelvin data
with thresholds below 100 are converted to Celsius, and precipitation in
metres to millimetres, with a message. Percentiles of precipitation
leave out days below 0.1 mm unless `control` says otherwise.

`survey` may be a named list of surveys (waves, countries); each is
processed in turn and the results are stacked with a `survey` column.

## See also

[`climate_indices()`](https://jmr-fao.github.io/c4e/reference/climate_indices.md),
[`list_presets()`](https://jmr-fao.github.io/c4e/reference/list_presets.md),
[`write_stata()`](https://jmr-fao.github.io/c4e/reference/write_stata.md)

## Examples

``` r
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)

weather_extremes(survey,
                 system.file("extdata", "tmax_daily.tif", package = "c4e"),
                 id = hhid, interview = interview, preset = "heat")
#> Using lat as `lat`.
#> Using lon as `lon`.
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
#> ℹ weather_extremes (heat): tmax in K, daily, 2021-01-01 to 2023-12-31
#>   above 30, 35 C; spells of 2+ days
#>   window: 1 year before the interview
#>   12 locations, 20 survey units
#> ℹ Extracting tmax
#> Converting "K" to "C" to read the thresholds.
#> ✔ Extracting tmax [151ms]
#> 
#> ℹ Computing indicators
#> Using `unit = "C"` from upstream unit.
#> ✔ Computing indicators [139ms]
#> 
#> ℹ Summarising over the reference windows
#> ✔ Summarising over the reference windows [116ms]
#> 
#> # A tibble: 20 × 14
#> # Context:  tmax [C], day, summary; key hhid; 12 indicators
#>    hhid    lag day_abv_30_sum C_abv_30_sum day_abv_35_sum C_abv_35_sum
#>    <chr> <int>          <dbl>        <dbl>          <dbl>        <dbl>
#>  1 HH01      0            103         235.              4        1.84 
#>  2 HH02      0            140         419.             28       24.6  
#>  3 HH03      0            105         233.              5        4.38 
#>  4 HH04      0             81         153.              3        1.39 
#>  5 HH05      0            121         277.             14        9.52 
#>  6 HH06      0            100         231.              6        4.80 
#>  7 HH07      0            136         366.             11       11.0  
#>  8 HH08      0            103         235.              4        1.84 
#>  9 HH09      0            113         280.              8       10.4  
#> 10 HH10      0             89         183.              1        0.790
#> 11 HH11      0            127         397.             28       27.2  
#> 12 HH12      0            105         233.              7        2.93 
#> 13 HH13      0             81         147.              3        1.39 
#> 14 HH14      0            119         300.              8        9.40 
#> 15 HH15      0            118         271.             14        9.52 
#> 16 HH16      0            104         230.              4        5.88 
#> 17 HH17      0             98         253.             12        9.95 
#> 18 HH18      0            125         367.             14       15.8  
#> 19 HH19      0            103         234.              6        4.80 
#> 20 HH20      0             94         251.             12        9.95 
#> # ℹ 8 more variables: spell_abv_30_max <dbl>, spell_abv_30_mean <dbl>,
#> #   spell_abv_30_sum <dbl>, spell_abv_30_n <int>, spell_abv_35_max <dbl>,
#> #   spell_abv_35_mean <dbl>, spell_abv_35_sum <dbl>, spell_abv_35_n <int>
```
