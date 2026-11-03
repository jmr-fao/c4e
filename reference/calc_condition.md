# Flag days that meet a condition

Adds one logical column per condition, written as an expression on the
table's columns, for example `hot_humid = value > 30 & rh > 60` on a
table joined with humidity. The columns are registered as flags, so
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md)
and the window summaries treat them like thresholds.

## Usage

``` r
calc_condition(x, ..., id = NULL, label = NULL)
```

## Arguments

- x:

  A wide table from `extract_*()`, or a long indicator table.

- ...:

  Named conditions, each giving `TRUE` or `FALSE` per row.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

## Value

A long `c4e_tbl` with one new column per condition.

## See also

Other indicators:
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md),
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
[`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
[`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
                 value = c(28, 31, 33, 29, 31)),
  key = "ID", date_col = "date", shape = "long", unit = "C")
calc_condition(x, warm = value > 30, mild = value > 27 & value <= 30)
#> # A tibble: 5 × 5
#> # Context:  value [C], long; key ID; 2 indicators
#>   ID    date       value warm  mild 
#>   <chr> <date>     <dbl> <lgl> <lgl>
#> 1 1     2022-01-01    28 FALSE TRUE 
#> 2 1     2022-01-02    31 TRUE  FALSE
#> 3 1     2022-01-03    33 TRUE  FALSE
#> 4 1     2022-01-04    29 FALSE TRUE 
#> 5 1     2022-01-05    31 TRUE  FALSE
```
