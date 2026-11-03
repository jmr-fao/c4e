# Aggregate cell indicators to administrative divisions

Averages cell-level indicators within each administrative division,
weighting each cell by the share of it inside the division
(`coverage_fraction` from
[`extract_cell_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_cell_by_poly.md)).
Replaces `agg_to_adm_div()`.

## Usage

``` r
aggregate_to_adm(
  x,
  cols = NULL,
  extra_col = NULL,
  id = NULL,
  weights = "coverage_fraction"
)
```

## Arguments

- x:

  A table of cell-level indicators with a coverage column.

- cols:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Columns to average; by default the registered indicators.

- extra_col:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Columns carried through; they must be constant within each division.

- id:

  Optional name of the division column; by default `ID_adm_div`.

- weights:

  Name of the weight column.

## Value

A `c4e_tbl` with one row per division (and lag or date).

## Details

Rows are grouped by the division and, when present, by `lag`, the date,
`month` or `period`. On daily flags this gives the share of the
division's area beyond the threshold each day; summed over a window by
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md),
it gives area-weighted days.

The columns averaged are the registered indicators by default.

## Examples

``` r
tmax <- read_climate(system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))

extract_cell_by_poly(tmax[[1:10]], adm_div) |>
  calc_threshold_day(above = 300) |>
  aggregate_to_adm()
#> Using `unit = "K"` from upstream unit.
#> # A tibble: 30 × 4
#> # Context:  tmax [K], day, long; key ID_adm_div; 2 indicators
#>    ID_adm_div date       day_abv_300 K_abv_300
#>    <chr>      <date>           <dbl>     <dbl>
#>  1 1          2021-01-01           0         0
#>  2 1          2021-01-02           0         0
#>  3 1          2021-01-03           0         0
#>  4 1          2021-01-04           0         0
#>  5 1          2021-01-05           0         0
#>  6 1          2021-01-06           0         0
#>  7 1          2021-01-07           0         0
#>  8 1          2021-01-08           0         0
#>  9 1          2021-01-09           0         0
#> 10 1          2021-01-10           0         0
#> # ℹ 20 more rows
```
