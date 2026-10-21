# Summarise indicators over each household's reference period

For every survey unit (household), summarises the daily (or monthly)
indicators of its location over the window before its interview: the
number of hot days in the 12 months before the interview, the longest
dry spell in the last rainy season, and so on. Replaces
`extr_day_by_interview()`, `extr_spell_by_interview()`,
`extr_day_index()` and `extr_spell_index()`.

## Usage

``` r
summarise_by_interview(
  survey,
  x,
  window = NULL,
  interval = NULL,
  n_lags = 0,
  by = NULL,
  id = NULL,
  interview = NULL,
  extra_col = NULL,
  stats = NULL,
  min_coverage = 0.8,
  label = NULL,
  chunk = "auto"
)
```

## Arguments

- survey:

  The survey, typically from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- x:

  A long indicator table, e.g. from
  [`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)
  and
  [`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md).

- window:

  A window from
  [`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_season()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_fixed()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
  or
  [`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md).

- interval, n_lags:

  Shortcut for `window = window_lag(interval, n_lags)`.

- by:

  Column linking the survey to `x`; by default the key of `x`.

- id:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Column identifying the survey units; by default the one recorded by
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- interview:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Interview dates: a column, or one date for everyone; by default the
  recorded column.

- extra_col:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Survey columns to carry into the result.

- stats:

  Optional named list of statistics per kind of indicator, e.g.
  `list(flag = c("sum", "mean"), spell = "max")`. Statistics: `"sum"`,
  `"mean"`, `"max"`, `"min"`, `"n"` (number of non-missing values).

- min_coverage:

  Share of the window that must be covered by data.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

A `c4e_tbl` with one row per survey unit and lag: the unit identifier,
`lag`, the extra columns and one column per indicator and statistic
(`day_abv_30_sum`, `spell_abv_30_max`), registered with the window.

## Details

The summaries follow the kind of each indicator in the registry: flags
and excesses are summed (days, degree-days), spells give their maximum,
mean, sum and count, standardised indices their mean. `stats` changes
this per kind.

A window with less than `min_coverage` of its days (months for monthly
data) present in the data gives `NA` rather than a count that looks
complete but is not, for example a window reaching before the start of
the data. Households without an interview date are left out and counted
in a message.

The computation runs once per location and interview date and is then
given to every household sharing them, and it is split by location when
it would exceed the memory budget.

## See also

[`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
[`summarise_by_period()`](https://jmr-fao.github.io/c4e/reference/summarise_by_period.md)

## Examples

``` r
tmax <- read_climate(system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)
coord <- prepare_coord(survey, lat, lon, id = hhid, interview = interview)

hot <- extract_by_coord(tmax, georef_coord(coord)) |>
  convert_unit("C") |>
  calc_threshold_day(above = 30) |>
  calc_spell()
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
#> Using `from = "K"` from upstream unit.
#> Using `unit = "C"` from upstream unit.

summarise_by_interview(coord, hot, interval = "1 year", n_lags = 1)
#> # A tibble: 40 × 8
#> # Context:  tmax [C], day, summary; key hhid; 6 indicators
#>    hhid    lag day_abv_30_sum C_abv_30_sum spell_abv_30_max spell_abv_30_mean
#>    <chr> <int>          <dbl>        <dbl>            <dbl>             <dbl>
#>  1 HH01      0            103         235.               29              8.31
#>  2 HH01      1             97         248.                9              4.31
#>  3 HH02      0            140         419.               38              8.31
#>  4 HH02      1            136         357.               70              8.79
#>  5 HH03      0            105         233.               22              5.88
#>  6 HH03      1             94         209.               20              4.35
#>  7 HH04      0             81         153.               13              4.29
#>  8 HH04      1             86         167.                9              3.63
#>  9 HH05      0            121         277.               57              8.67
#> 10 HH05      1            116         306.               31              6.8 
#> # ℹ 30 more rows
#> # ℹ 2 more variables: spell_abv_30_sum <dbl>, spell_abv_30_n <int>
```
