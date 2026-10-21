# Standardised precipitation indices: SPI and SPEI

Computes the Standardized Precipitation Index (SPI) or the Standardized
Precipitation-Evapotranspiration Index (SPEI) for every unit, at one or
more accumulation scales in months. Replaces `compute_spi()` of
climatic4economist, `compute_spei()` and `compute_water_balance()`.

## Usage

``` r
calc_std_index(x, ...)

# Default S3 method
calc_std_index(
  x,
  scale,
  index = c("spi", "spei"),
  pet = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto",
  .parallel = FALSE,
  ...
)
```

## Arguments

- x:

  Monthly precipitation (or water balance), wide from `extract_*()` or
  long.

- ...:

  Further arguments of the methods; the table method takes none.

- scale:

  Accumulation periods in months, e.g. `c(1, 3, 6)`.

- index:

  `"spi"` or `"spei"`.

- pet:

  For the SPEI, monthly potential evapotranspiration for the same units
  and dates, in the same unit as `x`.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

- .parallel:

  When `TRUE`, fit the series with `furrr`, following the user's
  [`future::plan()`](https://future.futureverse.org/reference/plan.html).

## Value

A long `c4e_tbl` with one column per scale, e.g. `spi_3`, registered
with the index and scale.

## Details

The data must be monthly. Daily rasters are aggregated first with
[`aggregate_time()`](https://jmr-fao.github.io/c4e/reference/aggregate_time.md),
before extraction.

For the SPEI, give potential evapotranspiration in `pet` (a table of the
same units and months): the water balance is precipitation minus its
absolute value, matched by unit and date, so ERA5's convention of
negative evaporation needs no change. Without `pet`, `x` is taken to be
the water balance already.

Each series is fitted on its own with
[`SPEI::spi()`](https://rdrr.io/pkg/SPEI/man/Drought-indices.html) or
[`SPEI::spei()`](https://rdrr.io/pkg/SPEI/man/Drought-indices.html).

## See also

[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md)

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
pre <- read_climate(
  system.file("extdata", "pre_monthly.tif", package = "c4e"))
#> Read pre_monthly: pre [mm/month], monthly, 1984-01-01 to 2023-12-01, 480 layers
#> (synthetic).
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")

extract_by_coord(pre, points) |>
  calc_std_index(scale = 3)
#> # A tibble: 5,760 × 6
#> # Context:  pre [mm/month], month, long; key ID; 1 indicator
#>    ID                x_cell y_cell date        value  spi_3
#>    <chr>              <dbl>  <dbl> <date>      <dbl>  <dbl>
#>  1 30.27330_-0.11150   30.3   -0.1 1984-01-01  16.6  NA    
#>  2 30.27330_-0.11150   30.3   -0.1 1984-02-01  21.4  NA    
#>  3 30.27330_-0.11150   30.3   -0.1 1984-03-01   7.60 -1.31 
#>  4 30.27330_-0.11150   30.3   -0.1 1984-04-01  95.8  -0.431
#>  5 30.27330_-0.11150   30.3   -0.1 1984-05-01  59.2  -0.703
#>  6 30.27330_-0.11150   30.3   -0.1 1984-06-01 132.    0.148
#>  7 30.27330_-0.11150   30.3   -0.1 1984-07-01  68.5  -0.305
#>  8 30.27330_-0.11150   30.3   -0.1 1984-08-01 107.    0.313
#>  9 30.27330_-0.11150   30.3   -0.1 1984-09-01  68.2   0.154
#> 10 30.27330_-0.11150   30.3   -0.1 1984-10-01   9.60  0.167
#> # ℹ 5,750 more rows
```
