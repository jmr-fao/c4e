# Weather extremes for every cell of a raster, in one call

The grid counterpart of
[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md):
the same presets and arguments, computed for every cell and summarised
per year or month instead of over the window before an interview. The
result is a raster with one layer per indicator and period, e.g.
`day_abv_30_sum_2021` or `spell_abv_30_max_2021`, for maps, panels of
grid cells or divisions, or extraction at many surveys at once.

## Usage

``` r
grid_indicators(
  climate,
  preset = NULL,
  above = NULL,
  below = NULL,
  p = NULL,
  spells = TRUE,
  min_spell = NULL,
  period = c("year", "month"),
  baseline = NULL,
  unit = NULL,
  filename = "",
  overwrite = FALSE,
  wopt = list(),
  control = extremes_control()
)
```

## Arguments

- climate:

  A daily raster: a file path or a `SpatRaster`.

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

- period:

  `"year"` or `"month"`.

- baseline:

  Optional dates `c(from, to)` for the percentiles.

- unit:

  Unit of the thresholds, when the data's should not be used.

- filename:

  Optional GeoTIFF to write the result to.

- overwrite:

  Overwrite `filename` when it exists.

- wopt:

  Options for writing, as in
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).

- control:

  Further options, see
  [`extremes_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md);
  its `min_coverage` applies to each period.

## Value

A `SpatRaster`, one layer per indicator and period; with `dry_run`,
`NULL`.

## Details

The raster is processed in blocks of rows, each block going through the
same steps as
[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md)
(thresholds or percentiles, spells, a summary per period with
[`summarise_by_period()`](https://jmr-fao.github.io/c4e/reference/summarise_by_period.md));
with `filename` the result is written to a GeoTIFF, so country-scale
daily stacks need not fit in memory. The indicator registry is kept in
the file's tags:
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
on the result gives the table, registry included, that the table path
gives.

## See also

[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md),
[`grid_controls()`](https://jmr-fao.github.io/c4e/reference/grid_controls.md),
[grid_methods](https://jmr-fao.github.io/c4e/reference/grid_methods.md)

## Examples

``` r
hot <- grid_indicators(
  system.file("extdata", "tmax_daily.tif", package = "c4e"),
  preset = "heat")
#> Converting "K" to "C" to read the thresholds.
#> ℹ grid_indicators (heat): tmax in K, daily
#>   above 30, 35 C; spells of 2+ days
#>   per year; 36 cells, 1095 layers
names(hot)
#>  [1] "day_abv_30_sum_2021"    "day_abv_30_sum_2022"    "day_abv_30_sum_2023"   
#>  [4] "C_abv_30_sum_2021"      "C_abv_30_sum_2022"      "C_abv_30_sum_2023"     
#>  [7] "day_abv_35_sum_2021"    "day_abv_35_sum_2022"    "day_abv_35_sum_2023"   
#> [10] "C_abv_35_sum_2021"      "C_abv_35_sum_2022"      "C_abv_35_sum_2023"     
#> [13] "spell_abv_30_max_2021"  "spell_abv_30_max_2022"  "spell_abv_30_max_2023" 
#> [16] "spell_abv_30_mean_2021" "spell_abv_30_mean_2022" "spell_abv_30_mean_2023"
#> [19] "spell_abv_30_sum_2021"  "spell_abv_30_sum_2022"  "spell_abv_30_sum_2023" 
#> [22] "spell_abv_30_n_2021"    "spell_abv_30_n_2022"    "spell_abv_30_n_2023"   
#> [25] "spell_abv_35_max_2021"  "spell_abv_35_max_2022"  "spell_abv_35_max_2023" 
#> [28] "spell_abv_35_mean_2021" "spell_abv_35_mean_2022" "spell_abv_35_mean_2023"
#> [31] "spell_abv_35_sum_2021"  "spell_abv_35_sum_2022"  "spell_abv_35_sum_2023" 
#> [34] "spell_abv_35_n_2021"    "spell_abv_35_n_2022"    "spell_abv_35_n_2023"   
```
