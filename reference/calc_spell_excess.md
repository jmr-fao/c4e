# Spells longer than usual

Compares each spell with the spell-length percentiles of its unit and
month from
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
and records by how many days it exceeds them (`NA` for shorter spells
and for days that end no spell). Each percentile column is matched with
the spell it was computed from through the registry. Replaces
`find_extr_spell_rel()` of climatic4economist.

## Usage

``` r
calc_spell_excess(x, pct, id = NULL, label = NULL, chunk = "auto")
```

## Arguments

- x:

  A long table with spell columns, from
  [`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md).

- pct:

  A spell-percentile table from
  [`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md).

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

`x` with one column per percentile, named like it, e.g.
`spell_abv_30_90p`.

## See also

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:9,
                 value = c(31, 32, 29, 33, 34, 35, 28, 31, 32, 33)),
  key = "ID", date_col = "date", shape = "long", unit = "C")
spells <- calc_threshold_day(x, above = 30) |> calc_spell()
#> Using `unit = "C"` from upstream unit.
calc_spell_excess(spells, calc_spell_percentile(spells, p = 0.5))
#> Using `min_spell = 2L` from upstream spell.
#> # A tibble: 10 × 7
#> # Context:  value [C], long; key ID; 4 indicators
#>    ID    date       value day_abv_30 C_abv_30 spell_abv_30 spell_abv_30_50p
#>    <chr> <date>     <dbl> <lgl>         <dbl>        <int>            <int>
#>  1 1     2022-01-01    31 TRUE              1           NA               NA
#>  2 1     2022-01-02    32 TRUE              2            2               NA
#>  3 1     2022-01-03    29 FALSE             0           NA               NA
#>  4 1     2022-01-04    33 TRUE              3           NA               NA
#>  5 1     2022-01-05    34 TRUE              4           NA               NA
#>  6 1     2022-01-06    35 TRUE              5            3                0
#>  7 1     2022-01-07    28 FALSE             0           NA               NA
#>  8 1     2022-01-08    31 TRUE              1           NA               NA
#>  9 1     2022-01-09    32 TRUE              2           NA               NA
#> 10 1     2022-01-10    33 TRUE              3            3                0
```
