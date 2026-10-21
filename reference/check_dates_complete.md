# Check Completeness of a Date Sequence

This function checks whether a vector of dates is sequential without
missing years, months, or days. It can return detailed information about
missing units and an overall continuity flag.

## Usage

``` r
check_dates_complete(
  dates,
  freq = c("year", "month", "day"),
  return_missing = FALSE
)
```

## Arguments

- dates:

  A vector of dates (class `Date`, `POSIXct`, or character convertible
  to Date).

- freq:

  Character vector specifying which levels to check: `"year"`,
  `"month"`, `"day"`. Default is all three.

- return_missing:

  Logical. If TRUE, returns exact missing years, months, and days.

## Value

A list containing:

- all_continuous:

  TRUE if the dates are fully sequential at requested frequency.

- year_check:

  TRUE if years are continuous, FALSE otherwise.

- month_issues:

  Data frame of years with missing months or incorrect days.

- day_issues:

  Data frame of year-month combinations with missing days.

- missing:

  Optional list of exact missing units (years, months, days), only if
  `return_missing = TRUE`.

## Examples

``` r
dates <- seq.Date(as.Date("2020-01-01"), as.Date("2021-12-31"), by = "day")
check_dates_complete(dates)
#> $year_check
#> [1] TRUE
#> 
#> $month_issues
#> # A tibble: 0 × 6
#> # ℹ 6 variables: year <dbl>, n_month <int>, n_day <int>, is_leap <lgl>,
#> #   flag_month <lgl>, flag_day <lgl>
#> 
#> $day_issues
#> # A tibble: 0 × 5
#> # ℹ 5 variables: year <dbl>, month <dbl>, n_day <int>, expected_days <int>,
#> #   flag_day <lgl>
#> 
#> $all_continuous
#> [1] TRUE
#> 

# a missing day is reported
check_dates_complete(dates[-45], return_missing = TRUE)
#> $year_check
#> [1] TRUE
#> 
#> $missing_years
#> integer(0)
#> 
#> $month_issues
#> # A tibble: 0 × 6
#> # ℹ 6 variables: year <dbl>, n_month <int>, n_day <int>, is_leap <lgl>,
#> #   flag_month <lgl>, flag_day <lgl>
#> 
#> $day_issues
#> # A tibble: 1 × 5
#>    year month n_day expected_days flag_day
#>   <dbl> <dbl> <int>         <int> <lgl>   
#> 1  2020     2    28            29 TRUE    
#> 
#> $missing_days
#> $missing_days$`2020-2`
#> [1] "2020-02-14"
#> 
#> 
#> $all_continuous
#> [1] FALSE
#> 
```
