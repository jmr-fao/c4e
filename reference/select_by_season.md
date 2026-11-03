# Select Columns of a Data Frame Corresponding to a Seasonal Period

Keeps the observations that fall within a seasonal range of months: the
date columns of a wide table, or the layers of a raster. Identifier
columns are kept.

## Usage

``` r
select_by_season(x, start_month, end_month, ...)

# S3 method for class 'data.frame'
select_by_season(x, start_month, end_month, ...)

# S3 method for class 'SpatRaster'
select_by_season(x, start_month, end_month, ...)
```

## Arguments

- x:

  A `data.frame` or `tibble` with identifier columns and date-labeled
  columns (e.g. "2021-04-01", "X2022.07.15"), or a `SpatRaster` with
  dates.

- start_month:

  The starting month of the seasonal window. Can be provided as an
  integer (1 to 12), a month abbreviation (e.g., `"Apr"`), or a full
  month name (e.g., `"April"`).

- end_month:

  The ending month of the seasonal window. Same format as `start_month`.

- ...:

  Unused.

## Value

`x` restricted to the months of the season. A raster keeps its context.

## Details

If `start_month <= end_month`, the function returns all observations
between those two months (inclusive). If `start_month > end_month`, the
season crosses the year boundary (e.g., November to February).

Date columns are those whose name starts with a year, optionally after
an `X`.

## Examples

``` r
df <- data.frame(
  ID = 1,
  "2021-01-01" = 10,
  "2021-04-01" = 15,
  "2021-07-01" = 20,
  "2021-11-01" = 25,
  check.names = FALSE
)

# Select April to July
select_by_season(df, "Apr", "Jul")
#>   ID 2021-04-01 2021-07-01
#> 1  1         15         20

# Select November to February (crosses year boundary)
select_by_season(df, 11, 2)
#>   ID 2021-01-01 2021-11-01
#> 1  1         10         25
```
