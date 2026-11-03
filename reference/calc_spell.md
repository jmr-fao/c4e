# Spells of consecutive flagged days

For every flag column registered by an earlier step (thresholds,
percentiles, conditions), finds runs of consecutive flagged days and
records the length of each run of at least `min_spell` days on its last
day. `day_abv_30` gives `spell_abv_30`. Replaces `find_spell()` of
climatic4economist.

## Usage

``` r
calc_spell(x, min_spell = NULL, id = NULL, label = NULL, chunk = "auto")
```

## Arguments

- x:

  A long table with flag columns, e.g. from
  [`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md).

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

`x` with one spell column per flag column, integer, `NA` except on the
last day of each spell.

## Details

`min_spell` defaults to the one used by earlier spells of the same
table, announced, and otherwise to 2. A missing value ends a run.

## See also

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:5,
                 value = c(31, 32, 29, 33, 34, 35)),
  key = "ID", date_col = "date", shape = "long", unit = "C")
calc_threshold_day(x, above = 30) |> calc_spell(min_spell = 2)
#> Using `unit = "C"` from upstream unit.
#> # A tibble: 6 × 6
#> # Context:  value [C], long; key ID; 3 indicators
#>   ID    date       value day_abv_30 C_abv_30 spell_abv_30
#>   <chr> <date>     <dbl> <lgl>         <dbl>        <int>
#> 1 1     2022-01-01    31 TRUE              1           NA
#> 2 1     2022-01-02    32 TRUE              2            2
#> 3 1     2022-01-03    29 FALSE             0           NA
#> 4 1     2022-01-04    33 TRUE              3           NA
#> 5 1     2022-01-05    34 TRUE              4           NA
#> 6 1     2022-01-06    35 TRUE              5            3
```
