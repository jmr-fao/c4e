# Select time observations based on interview date and time interval

This function filters a dataframe based on an interview date and a
specified time interval. It can accept an existing column name, a
literal character string, or a Date object for the interview date.

## Usage

``` r
select_by_interview(df, interview, interval, wide = FALSE)
```

## Arguments

- df:

  A dataframe containing longitudinal data with date-based columns
  (identified by a 4-digit year pattern).

- interview:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>.
  Either an existing column name containing dates, or a single value
  (Date or character) to be applied to all rows.

- interval:

  A string specifying the time range for selection (e.g., `"2 years"`,
  `"6 months"`). Passed to `filter_by_interview`.

- wide:

  Logical. If `TRUE`, returns the data in wide format. If `FALSE`
  (default), returns long format.

## Value

A filtered tibble/dataframe. If `wide = TRUE`, the columns matching the
date pattern are restored to the wide headers.

## Details

If `interview` is not a column name found in `df`, the function creates
a temporary reference column using the value provided. Rows with missing
interview dates are automatically dropped, and a message is displayed
indicating the count of dropped rows.

The function identifies data columns to pivot by searching for 4-digit
years (e.g., "2023", "X2023_01_01") in the column names.

## Examples

``` r
# Usage with a column name:
df <- data.frame(
  id = 1:2,
  interview_date = as.Date(c("2023-01-15", "2022-06-20")),
  X2022_12_02 = c(100, 200),
  X2022_06_21 = c(150, 250)
)
select_by_interview(df, interview_date, "1 year")
#> # A tibble: 2 × 4
#>      id interview_date date        value
#>   <int> <date>         <chr>       <dbl>
#> 1     1 2023-01-15     X2022_12_02   100
#> 2     1 2023-01-15     X2022_06_21   150

# Usage with a literal date:
select_by_interview(df, "2023-01-01", "6 months", wide = TRUE)
#> # A tibble: 2 × 3
#>      id interview_date X2022_12_02
#>   <int> <date>               <dbl>
#> 1     1 2023-01-15             100
#> 2     2 2022-06-20             200
```
