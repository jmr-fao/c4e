# The same window, one or more periods earlier

Sets how far back a window reaches, whichever kind it is: the lags of
[`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
and the earlier seasons of
[`window_season()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
and
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
are the same idea under two field names, and a caller building a
baseline should not have to know which one it holds.

## Usage

``` r
window_lags(window, back)
```

## Arguments

- window:

  A `c4e_window`.

- back:

  Which earlier periods: `0` is the window itself, `0:39` it and the
  thirty-nine before it. A lag window takes the highest, there being no
  gaps in a run of consecutive periods.

## Value

`window`, with its lags set.

## Details

[`window_fixed()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
is the same period for everyone and
[`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
runs from a date recorded per household, so neither has earlier periods
and both are refused.

## See also

[`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
[`calc_anomaly()`](https://jmr-fao.github.io/c4e/reference/calc_anomaly.md)

## Examples

``` r
window_lags(window_season("Jun", "Sep"), 0:29)
#> <c4e window: season Jun to Sep, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 season(s) back>
window_lags(window_lag("1 year"), 0:9)
#> <c4e window: 1 year before the interview, lags 0 to 9>
```
