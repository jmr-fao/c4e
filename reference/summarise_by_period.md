# Summarise indicators by calendar period

Summarises the indicators of each unit by month or year, for panels and
maps without a survey: hot days per month, the longest spell per year.
The statistics follow the registry as in
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md),
and a period with less than `min_coverage` of its days present gives
`NA`.

## Usage

``` r
summarise_by_period(
  x,
  period = c("month", "year"),
  stats = NULL,
  min_coverage = 0.8,
  id = NULL,
  label = NULL
)
```

## Arguments

- x:

  A long indicator table.

- period:

  `"month"` or `"year"`.

- stats:

  Optional named list of statistics per kind of indicator, e.g.
  `list(flag = c("sum", "mean"), spell = "max")`. Statistics: `"sum"`,
  `"mean"`, `"max"`, `"min"`, `"n"` (number of non-missing values).

- min_coverage:

  Share of the window that must be covered by data.

- id:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Column identifying the survey units; by default the one recorded by
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- label:

  Optional name shown in progress messages.

## Value

A long `c4e_tbl` with the unit identifiers, `period` (the date the
period starts) and one column per indicator and statistic, with the new
time step.

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:59,
                 value = rep(c(28, 31, 33), 20)),
  key = "ID", date_col = "date", shape = "long", unit = "C", time_step = "day")
calc_threshold_day(x, above = 30) |>
  summarise_by_period("month", min_coverage = 0)
#> Using `unit = "C"` from upstream unit.
#> # A tibble: 3 × 4
#> # Context:  value [C], month, long; key ID; 2 indicators
#>   ID    period     day_abv_30_sum C_abv_30_sum
#>   <chr> <date>              <dbl>        <dbl>
#> 1 1     2022-01-01             20           40
#> 2 1     2022-02-01             19           37
#> 3 1     2022-03-01              1            3
```
