# Flag months beyond thresholds of a standardised index

Flags, for every SPI or SPEI column registered by
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
the months below or above each threshold, e.g. `spi3_blw_-1.5` for a
3-month SPI below -1.5 (severe drought). The sign is kept in the name.
The flags are registered, so
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md)
finds drought spells and the window summaries count drought months.
Replaces `extr_std_index()` of climatic4economist.

## Usage

``` r
calc_std_threshold(
  x,
  above = NULL,
  below = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto"
)
```

## Arguments

- x:

  A long table from
  [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md).

- above, below:

  Thresholds on the index, e.g. `below = c(-1, -1.5, -2)`.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

`x` with one logical column per index column and threshold.

## See also

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
  calc_std_index(scale = 3) |>
  calc_std_threshold(below = c(-1, -1.5, -2))
#> # A tibble: 5,760 × 9
#> # Context:  pre [mm/month], month, long; key ID; 4 indicators
#>    ID       x_cell y_cell date        value  spi_3 `spi3_blw_-1` `spi3_blw_-1.5`
#>    <chr>     <dbl>  <dbl> <date>      <dbl>  <dbl> <lgl>         <lgl>          
#>  1 30.2733…   30.3   -0.1 1984-01-01  16.6  NA     NA            NA             
#>  2 30.2733…   30.3   -0.1 1984-02-01  21.4  NA     NA            NA             
#>  3 30.2733…   30.3   -0.1 1984-03-01   7.60 -1.31  TRUE          FALSE          
#>  4 30.2733…   30.3   -0.1 1984-04-01  95.8  -0.431 FALSE         FALSE          
#>  5 30.2733…   30.3   -0.1 1984-05-01  59.2  -0.703 FALSE         FALSE          
#>  6 30.2733…   30.3   -0.1 1984-06-01 132.    0.148 FALSE         FALSE          
#>  7 30.2733…   30.3   -0.1 1984-07-01  68.5  -0.305 FALSE         FALSE          
#>  8 30.2733…   30.3   -0.1 1984-08-01 107.    0.313 FALSE         FALSE          
#>  9 30.2733…   30.3   -0.1 1984-09-01  68.2   0.154 FALSE         FALSE          
#> 10 30.2733…   30.3   -0.1 1984-10-01   9.60  0.167 FALSE         FALSE          
#> # ℹ 5,750 more rows
#> # ℹ 1 more variable: `spi3_blw_-2` <lgl>
```
