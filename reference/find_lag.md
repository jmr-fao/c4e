# Compute the number of complete time intervals between two dates

This function calculates the number of complete time intervals (e.g.,
years, months, weeks, or days) between a start and an end date. It
supports both calendar-aware intervals (respecting actual month lengths
and leap years) and fixed-duration intervals (approximating months and
years with average lengths in days).

## Usage

``` r
find_lag(
  start,
  end,
  width = 1,
  unit = c("year", "month", "week", "day"),
  calendar = TRUE
)
```

## Arguments

- start:

  A `Date` or `POSIXt` object representing the start date.

- end:

  A `Date` or `POSIXt` object representing the end date.

- width:

  An integer specifying the width of the time interval. Defaults to 1.

- unit:

  A character string specifying the unit of time to measure (`"year"`,
  `"month"`, `"week"`, `"day"`). Defaults to `"year"`.

- calendar:

  Logical; if `TRUE`, computes calendar-aware intervals using real
  months and years. If `FALSE`, computes fixed-duration intervals using
  average days (365.25 for years, 30.4375 for months). Defaults to
  `TRUE`.

## Value

An integer (or numeric vector) representing the number of complete
intervals of the specified width between the start and end dates.

## Details

- When `calendar = TRUE`, the span is measured against the calendar: it
  counts **completed calendar months or years**, respecting variable
  month lengths and leap years. A month elapses when the day of the
  month comes round again, so 31 January to 28 February is one whole
  month.

- When `calendar = FALSE`, it is divided by a
  [`lubridate::duration()`](https://lubridate.tidyverse.org/reference/duration.html),
  a fixed span of seconds. A year is always 365.25 days (`dyears()`) and
  a month always 30.4375 days (`dmonths()`).

- Weeks and days are the same either way, since both are fixed multiples
  of a day.

The two modes disagree near a boundary. From 2021-01-01 to 2022-01-01 is
a complete calendar year, so `calendar = TRUE` returns 1; the same span
is 365 days, short of the 365.25-day fixed year, so `calendar = FALSE`
returns 0. Prefer `calendar = TRUE` when the lag must line up with
calendar reporting periods, and `calendar = FALSE` when equal-length
bins matter more.

Both modes count **whole units toward zero**, so a partial interval is
never rounded away from zero: a span of -31.2 years gives -31, not -32.
Mixing positive and negative lags in one call therefore makes the bin at
zero twice as wide as the others, since it holds everything within one
unit on either side. Every lag in a given call is normally the same
sign, so this rarely arises, but split the calls if it does.

`calendar = TRUE` costs more than `calendar = FALSE`, but not enough to
choose between them on speed: on a million dates monthly lags take
roughly 0.3 seconds against 0.01 seconds. Pick the mode that matches the
bins you want, not the one that runs faster.

## See also

[`clock::add_months()`](https://clock.r-lib.org/reference/clock-arithmetic.html),
[`lubridate::duration()`](https://lubridate.tidyverse.org/reference/duration.html)

## Examples

``` r
# Calendar-aware: number of full years between two dates
find_lag(as.Date("2020-01-01"), as.Date("2025-01-01"))
#> [1] -5

# Calendar-aware: number of 6-month intervals
find_lag(as.Date("2020-01-01"), as.Date("2023-01-01"),
         width = 6, unit = "month")
#> [1] -6

# Fixed-duration: approximate number of months using average 30.4375 days
find_lag(as.Date("2020-01-01"), as.Date("2023-01-01"),
         width = 6, unit = "month", calendar = FALSE)
#> [1] -6

# Calendar-aware: rolling month indices for daily dates
dates <- seq.Date(as.Date("2023-11-24"), as.Date("2025-11-24"), by = "day")
reference <- as.Date("2025-11-24")
find_lag(dates, reference, unit = "month")
#>   [1] -24 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23
#>  [19] -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -23 -22 -22 -22 -22 -22
#>  [37] -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22 -22
#>  [55] -22 -22 -22 -22 -22 -22 -22 -22 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21
#>  [73] -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21 -21
#>  [91] -21 -21 -21 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20
#> [109] -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -20 -19 -19 -19 -19
#> [127] -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19 -19
#> [145] -19 -19 -19 -19 -19 -19 -19 -19 -19 -18 -18 -18 -18 -18 -18 -18 -18 -18
#> [163] -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18 -18
#> [181] -18 -18 -18 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17
#> [199] -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -17 -16 -16
#> [217] -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -16
#> [235] -16 -16 -16 -16 -16 -16 -16 -16 -16 -16 -15 -15 -15 -15 -15 -15 -15 -15
#> [253] -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15 -15
#> [271] -15 -15 -15 -15 -15 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14
#> [289] -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14 -14
#> [307] -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13
#> [325] -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -13 -12 -12 -12 -12 -12 -12
#> [343] -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12 -12
#> [361] -12 -12 -12 -12 -12 -12 -12 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11
#> [379] -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11 -11
#> [397] -11 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10
#> [415] -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10 -10  -9  -9  -9  -9
#> [433]  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9  -9
#> [451]  -9  -9  -9  -9  -9  -9  -9  -9  -9  -8  -8  -8  -8  -8  -8  -8  -8  -8
#> [469]  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8  -8
#> [487]  -8  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7
#> [505]  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -6  -6  -6  -6
#> [523]  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6  -6
#> [541]  -6  -6  -6  -6  -6  -6  -6  -6  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5
#> [559]  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5  -5
#> [577]  -5  -5  -5  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4
#> [595]  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -4  -3  -3  -3
#> [613]  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3
#> [631]  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -2  -2  -2  -2  -2  -2  -2  -2
#> [649]  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -2
#> [667]  -2  -2  -2  -2  -2  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1
#> [685]  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1   0
#> [703]   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0
#> [721]   0   0   0   0   0   0   0   0   0   0   0   0
```
