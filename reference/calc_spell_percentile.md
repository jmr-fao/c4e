# Percentiles of spell lengths by unit and month

For each spell column, computes percentiles of the lengths of the spells
ending in each calendar month, per unit, over all years: the "unusually
long" spells that
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md)
compares with. A month without any spell gets `min_spell`. Values are
whole days (truncated), as in v1. Replaces `calc_pct_spell()` of
climatic4economist.

## Usage

``` r
calc_spell_percentile(
  x,
  p,
  min_spell = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto"
)
```

## Arguments

- x:

  A long table with spell columns (from
  [`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md))
  or flag columns.

- p:

  Probabilities, e.g. `c(0.5, 0.9)`.

- min_spell:

  Minimum number of consecutive days that make a spell.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

A `c4e_tbl` lookup table: the unit identifiers, `month` and one column
per spell and percentile, e.g. `spell_abv_30_90p`.

## Details

Spells are computed first when `x` only has flags.

## See also

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:9,
                 value = c(31, 32, 29, 33, 34, 35, 28, 31, 32, 33)),
  key = "ID", date_col = "date", shape = "long", unit = "C")
calc_threshold_day(x, above = 30) |>
  calc_spell() |>
  calc_spell_percentile(p = 0.9)
#> Using `unit = "C"` from upstream unit.
#> Using `min_spell = 2L` from upstream spell.
#> # A tibble: 1 × 3
#> # Context:  value [C], lookup; key ID; 1 indicator
#>   ID    month spell_abv_30_90p
#>   <chr> <chr>            <int>
#> 1 1     01                   3
```
