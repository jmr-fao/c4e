# Flag days beyond their unit's monthly percentiles

Compares each day with the percentile of its unit and calendar month
from
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md):
a day above the 90th percentile of July is flagged `day_abv_90p`, and
its distance above goes in `<unit>_abv_90p`. Replaces
`find_extr_rel_day()`.

## Usage

``` r
calc_percentile_day(
  x,
  pct,
  tail = NULL,
  unit = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto"
)
```

## Arguments

- x:

  A wide table from `extract_*()`, or a long indicator table.

- pct:

  A percentile table from
  [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md).

- tail:

  `NULL` to decide per column, or `"upper"` / `"lower"` for all.

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

A long `c4e_tbl` with flag and excess columns per percentile.

## Details

Whether a percentile is an upper or a lower threshold follows from its
probability (0.5 and above are upper), unless `tail` says otherwise; the
choice is announced. The percentiles must describe the same variable, in
the same unit, as `x`.

## See also

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
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

tmax_points <- extract_by_coord(tmax, points)
pct <- calc_percentile(tmax_points, p = c(0.1, 0.9))
calc_percentile_day(tmax_points, pct)
#> Using `unit = "K"` from upstream unit.
#> ℹ Percentiles of 0.5 and above are upper thresholds, the others lower.
#>   Flagging above: day_90p.
#>   Flagging below: day_10p.
#> # A tibble: 13,140 × 9
#> # Context:  tmax [K], day, long; key ID; 4 indicators
#>    ID           x_cell y_cell date       value day_blw_10p K_blw_10p day_abv_90p
#>    <chr>         <dbl>  <dbl> <date>     <dbl> <lgl>           <dbl> <lgl>      
#>  1 30.27330_-0…   30.3   -0.1 2021-01-01  293. FALSE           0     FALSE      
#>  2 30.27330_-0…   30.3   -0.1 2021-01-02  295. FALSE           0     FALSE      
#>  3 30.27330_-0…   30.3   -0.1 2021-01-03  294. FALSE           0     FALSE      
#>  4 30.27330_-0…   30.3   -0.1 2021-01-04  292. FALSE           0     FALSE      
#>  5 30.27330_-0…   30.3   -0.1 2021-01-05  294. FALSE           0     FALSE      
#>  6 30.27330_-0…   30.3   -0.1 2021-01-06  292. FALSE           0     FALSE      
#>  7 30.27330_-0…   30.3   -0.1 2021-01-07  290. TRUE            0.473 FALSE      
#>  8 30.27330_-0…   30.3   -0.1 2021-01-08  292. FALSE           0     FALSE      
#>  9 30.27330_-0…   30.3   -0.1 2021-01-09  294. FALSE           0     FALSE      
#> 10 30.27330_-0…   30.3   -0.1 2021-01-10  294. FALSE           0     FALSE      
#> # ℹ 13,130 more rows
#> # ℹ 1 more variable: K_abv_90p <dbl>
```
