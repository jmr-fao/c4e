# Merge survey observations with other data.

The two tables are matched on the column identifying the units.

## Usage

``` r
merge_with_survey(survey, new_value, iteration = NULL, id = NULL, label = NULL)
```

## Arguments

- survey:

  A data frame. It must contain the unit identifier column used for the
  merging.

- new_value:

  A data frame. The data to be merge with the survey. It must carry the
  same identifier column as `survey`.

- iteration:

  Deprecated; use `label`.

- id:

  Optional character string naming the column that identifies the units.
  When `NULL`, `ID` is used, or `ID_adm_div` when that is the only one
  present.

- label:

  Optional name shown in progress messages.

## Value

A [tbl_df](https://tibble.tidyverse.org/reference/tbl_df-class.html),
with variables from the survey and new weather values: a `c4e_tbl` with
the context of `new_value` when it has one, recording which columns came
from the survey.

## Details

Joining a long daily table onto a survey repeats every day for every
household at the location, which grows quickly; when the result would
exceed the memory budget a warning points to
[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md),
which summarises each household's reference period without building the
joined table.

## See also

[`dplyr::full_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)

## Examples

``` r
tmax <- terra::rast(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
survey <- read.csv(
  system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")
tmax_points <- extract_by_coord(tmax[[1:5]], points)

merge_with_survey(coord, tmax_points)
#> # A tibble: 20 × 12
#> # Context:  value [K], day, wide; key ID
#>    ID      hhid    lon     lat interview x_cell y_cell `2021-01-01` `2021-01-02`
#>    <chr>   <chr> <dbl>   <dbl> <chr>      <dbl>  <dbl>        <dbl>        <dbl>
#>  1 30.876… HH02   30.9 -0.879  2023-03-…   30.9   -0.9         296.         298.
#>  2 30.450… HH12   30.4 -0.703  2023-05-…   30.5   -0.7         295.         292.
#>  3 30.858… HH11   30.9 -0.390  2023-04-…   30.9   -0.3         295.         296.
#>  4 30.770… HH05   30.8 -0.372  2023-04-…   30.7   -0.3         294.         295.
#>  5 30.770… HH15   30.8 -0.372  2023-05-…   30.7   -0.3         294.         295.
#>  6 30.432… HH06   30.4 -0.343  2023-03-…   30.5   -0.3         292.         294.
#>  7 30.432… HH16   30.4 -0.343  2023-06-…   30.5   -0.3         292.         294.
#>  8 30.432… HH19   30.4 -0.343  2023-06-…   30.5   -0.3         292.         294.
#>  9 30.412… HH03   30.4 -0.300  2023-06-…   30.5   -0.3         292.         294.
#> 10 30.381… HH04   30.4 -0.203  2023-05-…   30.3   -0.3         293.         293.
#> 11 30.381… HH13   30.4 -0.203  2023-06-…   30.3   -0.3         293.         293.
#> 12 30.688… HH09   30.7 -0.194  2023-07-…   30.7   -0.1         293.         294.
#> 13 30.688… HH14   30.7 -0.194  2023-08-…   30.7   -0.1         293.         294.
#> 14 30.273… HH10   30.3 -0.112  2023-08-…   30.3   -0.1         293.         295.
#> 15 30.519… HH01   30.5  0.0651 2023-08-…   30.5    0.1         290.         296.
#> 16 30.519… HH20   30.5  0.0651 2023-05-…   30.5    0.1         290.         296.
#> 17 30.897… HH07   30.9  0.120  2023-06-…   30.9    0.1         295.         294.
#> 18 30.897… HH18   30.9  0.120  2023-03-…   30.9    0.1         295.         294.
#> 19 30.415… HH08   30.4  0.141  2023-07-…   30.5    0.1         290.         296.
#> 20 30.415… HH17   30.4  0.141  2023-04-…   30.5    0.1         290.         296.
#> # ℹ 3 more variables: `2021-01-03` <dbl>, `2021-01-04` <dbl>,
#> #   `2021-01-05` <dbl>
```
