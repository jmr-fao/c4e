# Climatic parameters per unit

Computes summary statistics of each unit's series, such as the long-run
mean and standard deviation of temperature, or the average yearly
rainfall.

## Usage

``` r
calc_par(x, ...)

# Default S3 method
calc_par(
  x,
  fn,
  period = NULL,
  min_coverage = 0.8,
  prefix = NULL,
  suffix = NULL,
  id = NULL,
  label = NULL,
  chunk = "auto",
  ...
)
```

## Arguments

- x:

  A wide table from `extract_*()`, or a long table.

- ...:

  Further arguments of the methods; the table method takes none.

- fn:

  The statistics: a named list of functions
  (`list(avg = mean, total = sum)`), a character vector of function
  names (`c("mean", "sd")`) or a single function. Functions receive the
  values with any `NA`, so handle them as needed
  (`\(v) mean(v, na.rm = TRUE)`).

- period:

  `NULL` (all observations together), `"year"` or `"month"`.

- min_coverage:

  Number between 0 and 1: the share of a month's days that must be
  present for the month to count. Used only when `period = "month"`.

- prefix:

  Column name prefix; by default the variable, `FALSE` for none.

- suffix:

  Optional column name suffix.

- id:

  Optional name of the unit identifier column.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` splits the work by unit when it would not fit in memory; a
  whole number forces that many units per chunk; `FALSE` never splits.

## Value

A `c4e_tbl` with one row per unit: its identifiers and one column per
statistic, registered with the statistic and period.

## Details

With `period`, the statistics are first computed within each period and
then averaged across periods: `fn = list(total = sum), period = "year"`
gives the average yearly total. Periods are counted back from the last
date of the data, so the last period always ends on the last
observation: yearly periods are the 12-month windows ending there,
monthly periods the one-month windows. When the last date is not the end
of December (yearly) or of a month (monthly), a warning says so, because
the windows then do not follow calendar years or months.

Columns are named `<prefix>_<statistic>_<suffix>`. The prefix defaults
to the variable recorded upstream (announced), so a temperature table
gives `tmax_mean`, `tmax_sd`.

## Monthly coverage

With `period = "month"` a month represented by only a handful of days
would enter the average as though it were complete. `min_coverage`
guards against this by comparing the observations present in each window
with the number of days it spans. If no month reaches it, the function
stops; the most common cause is data already at monthly resolution, for
which `period = NULL` or `period = "year"` are the right choices.
Monthly input asked for monthly periods is refused at once.

## Coefficient of variation of temperatures

A coefficient of variation divides by the mean, so it needs a scale with
a true zero. Celsius and Fahrenheit have none: the same place would
score differently in each, and a place averaging 0 C would divide by
zero. Statistics named `cv` (or with `cv` as a word of their name, such
as `temp_cv`), and
[`cv()`](https://jmr-fao.github.io/c4e/reference/cv.md) itself, are
therefore computed on kelvin when the data are in C or F, with a
message; the registry records `ratio_unit = "K"`. The values look small,
since the mean in the denominator is near 273 rather than 20. Data with
no recorded unit whose variable is a temperature give a warning, because
the scale is unknown.

## See also

Other indicators:
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
[`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md),
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
df <- data.frame(
  ID = c(1, 2),
  `200101` = c(10, 20),
  `200102` = c(15, 25),
  `200201` = c(5, 15),
  `200202` = c(10, 20),
  check.names = FALSE
)

# Mean across all observations
calc_par(df, fn = list(avg = mean))
#> # A tibble: 2 × 2
#> # Context:  summary; key ID; 1 indicator
#>      ID   avg
#>   <dbl> <dbl>
#> 1     1    10
#> 2     2    20

# Average of yearly totals
calc_par(df, fn = list(total = sum), period = "year")
#> Warning: The last date (2002-02-01) is not the last day of a month and/or not in
#> December.
#> ℹ Yearly periods are the 12-month windows ending on it, not calendar years.
#> # A tibble: 2 × 2
#> # Context:  summary; key ID; 1 indicator
#>      ID total
#>   <dbl> <dbl>
#> 1     1    20
#> 2     2    40
```
