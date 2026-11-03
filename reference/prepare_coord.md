# Prepare ID for unique occurrences

Adds an `ID` column identifying each unique location, and records which
columns hold the coordinates, the household identifier and the interview
date, so later steps
([`georef_coord()`](https://jmr-fao.github.io/c4e/reference/georef_coord.md),
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md))
find them without being told again.

## Usage

``` r
prepare_coord(
  df,
  lat_var,
  lon_var,
  id = NULL,
  interview = NULL,
  id_rule = c("coordinates", "sequence"),
  digits = 5
)
```

## Arguments

- df:

  A data frame.

- lat_var:

  variable with the latitude coordinate

- lon_var:

  variable with the longitude coordinate

- id:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional column identifying the survey units (households), recorded
  for later steps.

- interview:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional column with the interview dates, recorded for later steps.

- id_rule:

  `"coordinates"` (stable IDs) or `"sequence"`.

- digits:

  Decimals of the coordinates in a coordinate ID.

## Value

A `c4e_tbl`: `df` with an `ID` column first, keyed by `ID`, with the
survey's columns recorded.

## Details

By default the ID is built from the coordinates themselves (longitude
and latitude rounded to `digits` decimals, e.g. `"30.12340_-0.54320"`),
so the same location gets the same ID in every wave, subset and run.
With `id_rule = "sequence"` the IDs are `"1"`, `"2"`, ... in the order
of the sorted coordinates, as in v1; they change whenever the set of
locations changes.

Rows are sorted by latitude and longitude.

## Examples

``` r
survey <- read.csv(
  system.file("extdata", "survey.csv", package = "c4e"))
prepare_coord(survey, lat_var = lat, lon_var = lon, id = hhid,
              interview = interview)
#> # A tibble: 20 × 5
#> # Context:  key ID
#>    ID                hhid    lon     lat interview 
#>    <chr>             <chr> <dbl>   <dbl> <chr>     
#>  1 30.87620_-0.87860 HH02   30.9 -0.879  2023-03-17
#>  2 30.45000_-0.70280 HH12   30.4 -0.703  2023-05-10
#>  3 30.85840_-0.39050 HH11   30.9 -0.390  2023-04-10
#>  4 30.77090_-0.37210 HH05   30.8 -0.372  2023-04-16
#>  5 30.77090_-0.37210 HH15   30.8 -0.372  2023-05-05
#>  6 30.43250_-0.34340 HH06   30.4 -0.343  2023-03-06
#>  7 30.43250_-0.34340 HH16   30.4 -0.343  2023-06-30
#>  8 30.43250_-0.34340 HH19   30.4 -0.343  2023-06-06
#>  9 30.41290_-0.30050 HH03   30.4 -0.300  2023-06-19
#> 10 30.38170_-0.20260 HH04   30.4 -0.203  2023-05-30
#> 11 30.38170_-0.20260 HH13   30.4 -0.203  2023-06-11
#> 12 30.68870_-0.19380 HH09   30.7 -0.194  2023-07-16
#> 13 30.68870_-0.19380 HH14   30.7 -0.194  2023-08-17
#> 14 30.27330_-0.11150 HH10   30.3 -0.112  2023-08-02
#> 15 30.51990_0.06510  HH01   30.5  0.0651 2023-08-01
#> 16 30.51990_0.06510  HH20   30.5  0.0651 2023-05-05
#> 17 30.89740_0.11990  HH07   30.9  0.120  2023-06-27
#> 18 30.89740_0.11990  HH18   30.9  0.120  2023-03-03
#> 19 30.41520_0.14090  HH08   30.4  0.141  2023-07-30
#> 20 30.41520_0.14090  HH17   30.4  0.141  2023-04-24
```
