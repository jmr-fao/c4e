# Location controls in the survey year, in one call

Takes, for each household, the layer of the year that matches its
survey: population, night lights, land cover by year. With `climate`, it
adds the climate normals of the `years` before the survey year. One row
per household and survey year.

## Usage

``` r
time_varying_controls(
  survey,
  layers = NULL,
  lat = NULL,
  lon = NULL,
  id = NULL,
  interview = NULL,
  year = NULL,
  match = c("same_year", "previous_year", "nearest"),
  climate = NULL,
  years = 30,
  stats = c("mean", "sd", "cv"),
  density = TRUE,
  log = "nightlight",
  buffer = 0,
  kind = NULL,
  boundaries = NULL,
  control = controls_control()
)
```

## Arguments

- survey:

  The survey: a data frame with coordinates, a household identifier and
  interview dates, or a table from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md);
  or a named list of them.

- layers:

  A named list of rasters with one layer per year, dated with
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html);
  e.g. `list(pop = worldpop)`.

- lat, lon, id, interview:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Survey columns: coordinates (found by name when left out), household
  identifier and interview date. Not needed after
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- year:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional survey column holding the survey year, instead of the
  interview date.

- match:

  `"same_year"`, `"previous_year"` or `"nearest"`.

- climate:

  Optional named list of climate rasters (paths or `SpatRaster`s) for
  the normals, e.g. `list(pre = chirps)`.

- years:

  Number of years before the survey year for the normals.

- stats:

  Statistics of the normals: any of `"mean"`, `"sd"`, `"cv"`, `"min"`,
  `"max"`, `"median"`, `"sum"`.

- density:

  Add the density of count layers.

- log:

  Names of layers to add as `log(1 + value)`.

- buffer:

  A radius in metres; 0 is the location's own cell.

- kind:

  Optional named character vector of layer kinds: `"continuous"`,
  `"count"` or `"categorical"`.

- boundaries:

  Optional administrative divisions: indicators are then computed per
  cell and averaged per division (area shares).

- control:

  Further options, see
  [`extremes_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md).

## Value

A `c4e_tbl` with one row per household and survey year.

## Details

`match` decides which yearly layer serves a survey year: the same year,
the previous one (to use only data from before the interview) or the
nearest available. The year used is kept in `<layer>_year`, and the
labels say which rule was applied. Count layers (population) also get
`<layer>_density`, per square kilometre of the cells summed; layers
named in `log` get `log_<layer>`, the log of one plus the value.

The normals use
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md) on
the series from `years` years before the survey year to the end of the
year before it; when the data cover fewer years, a message says which.

## See also

[`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md),
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md)

## Examples

``` r
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)
template <- terra::rast(system.file("extdata", "tmax_daily.tif",
                                    package = "c4e"))[[1]]
pop <- terra::rast(template, nlyrs = 3, vals = rep(c(100, 200, 300), each = 36))
terra::time(pop) <- as.Date(c("2021-01-01", "2022-01-01", "2023-01-01"))

time_varying_controls(survey, list(pop = pop), id = hhid,
                      interview = interview, match = "previous_year")
#> Using lat as `lat`.
#> Using lon as `lon`.
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
#> ℹ time_varying_controls: yearly layers
#>   layers: pop (previous_year)
#>   survey years: 2023
#>   12 locations, 20 survey units
#> ℹ Extracting 1 yearly layer
#> ✔ Extracting 1 yearly layer [109ms]
#> 
#> # A tibble: 20 × 5
#> # Context:  summary; key hhid; 2 indicators
#>    hhid  survey_year   pop pop_year pop_density
#>    <chr>       <int> <dbl>    <int>       <dbl>
#>  1 HH01         2023   200     2022       0.406
#>  2 HH02         2023   200     2022       0.406
#>  3 HH03         2023   200     2022       0.406
#>  4 HH04         2023   200     2022       0.406
#>  5 HH05         2023   200     2022       0.406
#>  6 HH06         2023   200     2022       0.406
#>  7 HH07         2023   200     2022       0.406
#>  8 HH08         2023   200     2022       0.406
#>  9 HH09         2023   200     2022       0.406
#> 10 HH10         2023   200     2022       0.406
#> 11 HH11         2023   200     2022       0.406
#> 12 HH12         2023   200     2022       0.406
#> 13 HH13         2023   200     2022       0.406
#> 14 HH14         2023   200     2022       0.406
#> 15 HH15         2023   200     2022       0.406
#> 16 HH16         2023   200     2022       0.406
#> 17 HH17         2023   200     2022       0.406
#> 18 HH18         2023   200     2022       0.406
#> 19 HH19         2023   200     2022       0.406
#> 20 HH20         2023   200     2022       0.406
```
