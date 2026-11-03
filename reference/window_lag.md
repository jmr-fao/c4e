# Reference windows for survey summaries

Describe the period before each interview over which
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)
summarises the indicators.

## Usage

``` r
window_lag(interval = "1 year", n_lags = 0)

window_season(start_month, end_month, years_back = 0)

window_fixed(from, to)

window_since(event)
```

## Arguments

- interval:

  Length of each lag, e.g. `"1 year"`, `"6 months"`, `"30 days"`.

- n_lags:

  Highest lag; `0` gives only the period just before the interview.

- start_month, end_month:

  Season bounds: numbers, abbreviations or month names.

- years_back:

  Which past seasons: `0` is the last one, `0:2` the last three.

- from, to:

  Dates of a fixed window, inclusive.

- event:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Column of the survey with the start date of each household's window.

## Value

A `c4e_window` object.

## Details

- `window_lag()`: consecutive periods of `interval` before the
  interview, e.g. the 12 months before it (lag 0) and the 12 months
  before those (lag 1). The interview day itself is never included.

- `window_season()`: the last season that ended before the interview,
  and earlier ones with `years_back`, e.g. the June to September rains.
  A season may cross the new year (`"Nov"` to `"Feb"`).

- `window_fixed()`: the same calendar period for everyone.

- `window_since()`: from a date recorded for each household, such as
  planting or a shock, up to the day before the interview.

## See also

[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)

## Examples

``` r
window_lag("1 year", n_lags = 2)
#> <c4e window: 1 year before the interview, lags 0 to 2>
window_season("Jun", "Sep", years_back = 0:1)
#> <c4e window: season Jun to Sep, 0, 1 season(s) back>
window_fixed("2022-01-01", "2022-12-31")
#> <c4e window: from 2022-01-01 to 2022-12-31>
```
