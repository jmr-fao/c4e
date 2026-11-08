# The dates a window specification resolves to

Turns a window from
[`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
[`window_season()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
[`window_fixed()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
or
[`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
into the dates it covers, for every location and interview date in
`data`: one row per key, interview and lag.

## Usage

``` r
window_dates(window, data, interview = NULL, by = NULL)
```

## Arguments

- window:

  A window from
  [`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_lags()`](https://jmr-fao.github.io/c4e/reference/window_lags.md),
  [`window_season()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_fixed()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
  or
  [`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md).

- data:

  A data frame holding the key column, the interview dates, and the
  columns named by `window` where it names any.

- interview:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  The column holding the interview date. Taken from the metadata after
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- by:

  Name of the column linking `data` to the indicator table, as a string.
  Taken from `data`'s metadata where it records a key.

## Value

A tibble with one row per distinct key, interview date and lag: the key
column under its own name, `interview`, `lag` (`0` for the window
closest to the interview, counting up as they recede), `w_start` and
`w_end`.

## Details

[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)
resolves windows this way before summarising. The same resolution is
exported here for the cases that do not go through a summary: cutting a
daily series to each household's growing season, joining windows onto a
table of one's own, or checking what a window actually covers before
relying on it.

Windows are half-open, `(w_start, w_end]`: a day equal to `w_start`
falls outside the window and a day equal to `w_end` falls inside it, so
that consecutive lags of the same window neither overlap nor leave a
gap.

Rows are dropped rather than returned with missing dates when they have
no interview date, no key, or – for
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
and
[`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
– no bounds. Resolving a window is therefore not a row-preserving
operation, and the result is distinct over the key and the interview
date: households sharing both share a window.

The season bounds of
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
and the event date of
[`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
are not arguments here. The window object already records which columns
of `data` hold them, so naming them twice is not possible.

## See also

[`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
for the window objects,
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)
for summarising a series over them.

## Examples

``` r
survey <- tibble::tibble(
    division  = c("a", "b"),
    interview = as.Date(c("2023-11-20", "2023-06-15")),
    sos       = c(92, 92),
    eos       = c(297, 297)
)

# the twelve months before each interview
window_dates(window_lag("1 year"), survey, interview, by = "division")
#> # A tibble: 2 × 5
#>   division interview    lag w_start    w_end     
#>   <chr>    <date>     <int> <date>     <date>    
#> 1 a        2023-11-20     0 2022-11-20 2023-11-19
#> 2 b        2023-06-15     0 2022-06-15 2023-06-14

# the last growing season to have closed before each interview: division b
# was interviewed inside the 2023 season, so it takes 2022's
window_dates(window_calendar(sos, eos), survey, interview, by = "division")
#> # A tibble: 2 × 5
#>   division interview    lag w_start    w_end     
#>   <chr>    <date>     <int> <date>     <date>    
#> 1 a        2023-11-20     0 2023-04-01 2023-10-24
#> 2 b        2023-06-15     0 2022-04-01 2022-10-24
```
