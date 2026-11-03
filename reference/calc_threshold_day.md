# Flag days beyond thresholds

For every unit and day, flags whether the value lies above or below each
threshold, and how far beyond it lies. Replaces `find_extr_abs_day()` of
climatic4economist.

## Usage

``` r
calc_threshold_day(x, ...)

# Default S3 method
calc_threshold_day(
  x,
  above = NULL,
  below = NULL,
  unit = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto",
  ...
)
```

## Arguments

- x:

  A wide table from `extract_*()`, or a long table from an earlier
  indicator step.

- ...:

  Further arguments of the methods; the table method takes none.

- above, below:

  Thresholds: numbers, or a table of thresholds by unit.

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

A long `c4e_tbl`: the unit identifiers, `date`, `value`, earlier
indicator columns, and the new flag and excess columns.

## Details

Thresholds are read in the unit of the data, which comes from upstream
(see
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md)
and
[`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)).
A `unit` that contradicts the data is refused, so 30 is never compared
with Kelvin by mistake.

A threshold is either a number, the same for every unit, or a table
keyed by unit (and optionally by `month`) with one column per threshold,
e.g. a threshold per agro-ecological zone or the percentiles of
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md).

Flag columns are named after the time step and the threshold:
`day_abv_30`, `day_blw_0.1` (`hr_` for hourly data, `mo_` for monthly).
Excess columns are named after the unit: `C_abv_30`, `mm_blw_0.1`. Each
is described in the table's registry, which later steps read.

## See also

[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md)

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md)

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

extract_by_coord(tmax[[1:60]], points) |>
  convert_unit("C") |>
  calc_threshold_day(above = c(30, 35))
#> Using `from = "K"` from upstream unit.
#> Using `unit = "C"` from upstream unit.
#> # A tibble: 720 × 9
#> # Context:  tmax [C], day, long; key ID; 4 indicators
#>    ID     x_cell y_cell date       value day_abv_30 C_abv_30 day_abv_35 C_abv_35
#>    <chr>   <dbl>  <dbl> <date>     <dbl> <lgl>         <dbl> <lgl>         <dbl>
#>  1 30.27…   30.3   -0.1 2021-01-01  19.4 FALSE             0 FALSE             0
#>  2 30.27…   30.3   -0.1 2021-01-02  22.1 FALSE             0 FALSE             0
#>  3 30.27…   30.3   -0.1 2021-01-03  21.0 FALSE             0 FALSE             0
#>  4 30.27…   30.3   -0.1 2021-01-04  19.0 FALSE             0 FALSE             0
#>  5 30.27…   30.3   -0.1 2021-01-05  21.3 FALSE             0 FALSE             0
#>  6 30.27…   30.3   -0.1 2021-01-06  19.3 FALSE             0 FALSE             0
#>  7 30.27…   30.3   -0.1 2021-01-07  17.1 FALSE             0 FALSE             0
#>  8 30.27…   30.3   -0.1 2021-01-08  18.4 FALSE             0 FALSE             0
#>  9 30.27…   30.3   -0.1 2021-01-09  21.1 FALSE             0 FALSE             0
#> 10 30.27…   30.3   -0.1 2021-01-10  21.3 FALSE             0 FALSE             0
#> # ℹ 710 more rows
```
