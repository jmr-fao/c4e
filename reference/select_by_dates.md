# Select time observations based on date range

Keeps the observations between two dates: the date columns of a wide
table, or the layers of a raster.

## Usage

``` r
select_by_dates(x, from = NULL, to = NULL, ...)

# S3 method for class 'data.frame'
select_by_dates(x, from = NULL, to = NULL, ...)

# S3 method for class 'SpatRaster'
select_by_dates(x, from = NULL, to = NULL, ...)
```

## Arguments

- x:

  A data frame with time-series data in wide format (one column per
  date), a `c4e_tbl`, or a `SpatRaster` with dates.

- from:

  character. A string representing the start date (optional).

- to:

  character. A string representing the end date (optional).

- ...:

  Unused.

## Value

`x` restricted to the dates between `from` and `to`. Columns that are
not dates are kept. A `c4e_tbl` records the new date range, and a raster
keeps its context.

## Details

The function requires both or just one between the starting date,
`from`, and the end date `to`. If both are provide the the function
select between the two dates. If only `from` is provided the function
selects all date after. If only `to` is provided the function selects
all date before. If none are provided returns the data unchanged.

Dates may be truncated, e.g. `"2022"` or `"2022-06"`. Date columns are
those whose name starts with a year, optionally after an `X`, so a
column such as `MAX_2020` is not taken for a date.

## Examples

``` r
df <- data.frame(X2022.12 = c(100, 200),
                 X2022.06 = c(150, 250))

select_by_dates(df, from = "2022-06-01", to = "2022-12-31")
#>   X2022.12 X2022.06
#> 1      100      150
#> 2      200      250

tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
select_by_dates(tmax, from = "2023-06-01", to = "2023-06-30")
#> class       : SpatRaster
#> size        : 6, 6, 30  (nrow, ncol, nlyr)
#> resolution  : 0.2, 0.2  (x, y)
#> extent      : 30, 31.2, -1, 0.2  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source      : tmax_daily.tif
#> varname     : tmax (c4e:variable=tmax;kind=continuous;source=synthetic;label=tmax_daily;time_step=day)
#> names       : 2023-06-01, 2023-06-02, 2023-06-03, 2023-06-04, 2023-06-05, 2023-06-06, ...
#> min values  :  301.06424, 298.318298, 301.583649, 299.440399, 300.054596, 301.520966, ...
#> max values  : 309.571899, 309.351685, 308.339844, 311.700653, 309.410461, 310.114105, ...
#> unit        : K
#> time (days) : 2023-06-01 to 2023-06-30 (30 steps)
```
