# Percentiles of daily values by unit and month

Computes, for each unit and calendar month, percentiles of the daily
values over all years of the baseline, e.g. the 90th percentile of
maximum temperature in July. These are the relative thresholds that
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md)
compares each day with. Replaces `calc_pct_day()`.

## Usage

``` r
calc_percentile(x, ...)

# Default S3 method
calc_percentile(
  x,
  p,
  exclude_below = NULL,
  exclude_above = NULL,
  min_threshold = NULL,
  max_threshold = NULL,
  yearly = FALSE,
  baseline = NULL,
  replace = NA_real_,
  id = NULL,
  label = NULL,
  chunk = "auto",
  ...
)
```

## Arguments

- x:

  A wide table from `extract_*()`, or a long indicator table.

- ...:

  Further arguments of the methods; the table method takes none.

- p:

  Probabilities, e.g. `c(0.1, 0.9)`.

- exclude_below, exclude_above:

  Values beyond these are left out.

- min_threshold, max_threshold:

  Absolute bounds on the percentile, in the data's unit, passed to
  [`bound_threshold()`](https://jmr-fao.github.io/c4e/reference/bound_threshold.md):
  a convenience for the common case, since the same bound applies to any
  threshold lookup table however it was produced. Use `min_threshold`
  with an upper tail and `max_threshold` with a lower one.

- yearly:

  When `TRUE`, also compute percentiles over all days of the year
  (columns `yr_90p`), repeated on every month.

- baseline:

  Optional dates `c(from, to)` limiting the days used, e.g.
  `c("1991-01-01", "2020-12-31")`.

- replace:

  Value for a unit and month with no data at all.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

A `c4e_tbl` lookup table: the unit identifiers, `month` (`"01"` to
`"12"`) and one column per percentile (`day_90p`), registered with their
probability and baseline.

## Details

`min_threshold` and `max_threshold` hand the finished lookup to
[`bound_threshold()`](https://jmr-fao.github.io/c4e/reference/bound_threshold.md),
which combines the percentile with an absolute guardrail so that one
definition of an extreme travels across climates.

Use `exclude_below` to leave out values, for instance days with less
than 0.1 mm of rain, so the percentiles describe wet days only. A unit
and month whose values all fall beyond the cut-off, such as a dry-season
month with no wet day, gets the cut-off itself as its percentiles, as in
climatic4economist: its days are then compared with the cut-off, so a
rare wet day still counts. A unit and month with no data at all gets
`replace` (by default `NA`, so no day is flagged against it).

## See also

[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md)

Other indicators:
[`bound_threshold()`](https://jmr-fao.github.io/c4e/reference/bound_threshold.md),
[`calc_anomaly()`](https://jmr-fao.github.io/c4e/reference/calc_anomaly.md),
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
pre <- read_climate(
  system.file("extdata", "pre_daily.tif", package = "c4e"))
#> Read pre_daily: pre [mm/day], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
survey <- read.csv(
  system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")

extract_by_coord(pre, points) |>
  calc_percentile(p = c(0.9, 0.99), exclude_below = 0.1)
#> # A tibble: 144 × 6
#> # Context:  pre [mm/day], day, lookup; key ID; 2 indicators
#>    ID                x_cell y_cell month day_90p day_99p
#>    <chr>              <dbl>  <dbl> <chr>   <dbl>   <dbl>
#>  1 30.27330_-0.11150   30.3   -0.1 01       16.1    47.6
#>  2 30.27330_-0.11150   30.3   -0.1 02       22.1    27.7
#>  3 30.27330_-0.11150   30.3   -0.1 03       17.8    19.0
#>  4 30.27330_-0.11150   30.3   -0.1 04       15.7    65.3
#>  5 30.27330_-0.11150   30.3   -0.1 05       21.8    23.6
#>  6 30.27330_-0.11150   30.3   -0.1 06       18.6    35.7
#>  7 30.27330_-0.11150   30.3   -0.1 07       25.8    52.1
#>  8 30.27330_-0.11150   30.3   -0.1 08       18.2    37.5
#>  9 30.27330_-0.11150   30.3   -0.1 09       12.9    35.3
#> 10 30.27330_-0.11150   30.3   -0.1 10       14.2    48.0
#> # ℹ 134 more rows
```
