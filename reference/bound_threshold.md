# Hold a threshold lookup table between absolute bounds

Raises a threshold to `min` where it falls below it, and lowers it to
`max` where it rises above it, leaving the rest untouched. The bound is
recorded on each threshold so that the flag, the excess and the label
all describe the threshold actually used.

## Usage

``` r
bound_threshold(x, min = NULL, max = NULL, cols = NULL)
```

## Arguments

- x:

  A threshold lookup table, from
  [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
  or built by the user, with registered threshold columns.

- min, max:

  Bounds in the data's unit: the threshold is held at or above `min` and
  at or below `max`. One number, or one for each column bounded.

- cols:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Columns to bound; by default every registered threshold column, the
  whole-year ones included.

## Value

`x` with the chosen columns bounded. A registered threshold also records
`min_threshold` and `max_threshold` on its entry, so the label and the
excess follow; a column named through `cols` that the registry does not
know is bounded without one being invented for it.

## Details

This combines a relative threshold with an absolute guardrail, which is
what makes one definition of an extreme travel across climates: the 95th
percentile of a mild month is not a hot day anywhere, and a fixed level
alone fires every year in the tropics and never in the highlands.
Passing both conditions is the same as passing the harder of the two, so
a single bounded threshold replaces a hand-written
`day_abv_99p & day_abv_30`.

Thresholds are lookup tables whoever produced them, so this works on a
table from
[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
and equally on agro-ecological zone limits, per-district thresholds or
crop-specific limits supplied by the user.

Give `min` for an upper threshold and `max` for a lower one, so that the
bound points the same way as the tail. The other pairing widens the
indicator instead of narrowing it, and is warned about. Where the bound
governs, the exceedance rate is no longer the nominal one; that is the
point of giving it.

## See also

[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)

Other indicators:
[`calc_anomaly()`](https://jmr-fao.github.io/c4e/reference/calc_anomaly.md),
[`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
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
path <- system.file("extdata", "tmax_daily.tif", package = "c4e")
if (FALSE) { # \dontrun{
pct <- calc_percentile(extracted, p = c(0.95, 0.99))

# A hot day is unusual for the place and month AND at least 25 C.
bound_threshold(pct, min = 25)
} # }
```
