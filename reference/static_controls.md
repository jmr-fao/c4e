# Location controls that do not change over time, in one call

Summarises layers with no time dimension at each household's location:
elevation and the terrain measures derived from it, agro-ecological
zones, land cover, soil, and distances to roads, markets, borders or
water. One row per household.

## Usage

``` r
static_controls(
  survey,
  layers,
  lat = NULL,
  lon = NULL,
  id = NULL,
  kind = NULL,
  buffer = 0,
  terrain = c("slope", "TRI", "roughness"),
  distance_to = NULL,
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

  A named list of single-layer rasters (or file paths), e.g.
  `list(elevation = dem, aez = zones)`.

- lat, lon, id:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Survey columns: coordinates (found by name when left out) and
  household identifier. Not needed after
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- kind:

  Optional named character vector of layer kinds: `"continuous"`,
  `"count"` or `"categorical"`.

- buffer:

  Radii in metres; 0 is the location's own cell.

- terrain:

  Terrain measures computed from an `elevation` layer; any of `"slope"`,
  `"TRI"`, `"roughness"`, `"aspect"`, `"TPI"`, or `NULL`.

- distance_to:

  Optional named list of `SpatVector`s; each adds `dist_<name>_km`, the
  distance to its nearest feature.

- boundaries:

  Optional administrative divisions to summarise over.

- control:

  Further options, see
  [`controls_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md).

## Value

A `c4e_tbl` with one row per household.

## Details

Each layer is treated by its kind: continuous layers are averaged,
counts summed and categorical layers (zones, classes) take their most
frequent value, so a category is never averaged. The kind is read from
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
or guessed from the layer's name (`aez`, `zone`, `land_cover`, `soil`,
`class` are categorical; `pop` is a count), or given with `kind`.

With `buffer`, each radius (in metres) adds one set of columns, named
with the radius: `elevation_20km`. A radius of 0 is the value of the
location's own cell. With an `elevation` layer, `terrain` adds slope (in
degrees), the terrain ruggedness index and roughness, computed from the
eight neighbouring cells; cells at the edge of the raster, where these
are missing, are filled from their neighbours when `fill_missing` is set
in `control` (the default). With `boundaries`, each household gets the
summary of its division instead; distances stay at its own location.

The chain:
[`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md),
[`georef_coord()`](https://jmr-fao.github.io/c4e/reference/georef_coord.md),
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
[`fill_missing_rast()`](https://jmr-fao.github.io/c4e/reference/fill_missing_rast.md),
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
(or
[`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md))
and
[`calc_nearest_distance()`](https://jmr-fao.github.io/c4e/reference/calc_nearest_distance.md).

## See also

[`time_varying_controls()`](https://jmr-fao.github.io/c4e/reference/time_varying_controls.md),
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)

## Examples

``` r
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
template <- terra::rast(system.file("extdata", "tmax_daily.tif",
                                    package = "c4e"))[[1]]
dem <- terra::rast(template, vals = seq(500, 1550, length.out = 36))

static_controls(survey, list(elevation = dem), id = hhid,
                buffer = c(0, 20000))
#> Using lat as `lat`.
#> Using lon as `lon`.
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
#> ℹ static_controls: static layers
#>   layers: elevation (continuous), slope (continuous), TRI (continuous),
#>   roughness (continuous)
#>   radii: 0, 20 km
#>   12 locations, 20 survey units
#> ℹ Extracting 4 layers
#> ✔ Extracting 4 layers [310ms]
#> 
#> # A tibble: 20 × 9
#> # Context:  summary; key hhid; 8 indicators
#>    hhid  elevation slope   TRI roughness elevation_20km slope_20km TRI_20km
#>    <chr>     <dbl> <dbl> <dbl>     <dbl>          <dbl>      <dbl>    <dbl>
#>  1 HH01        560 0.473  142.       420            650      0.473     142.
#>  2 HH02       1520 0.473  142.       420           1450      0.473     142.
#>  3 HH03        920 0.473  142.       420            905      0.473     142.
#>  4 HH04        890 0.473  142.       420            815      0.473     142.
#>  5 HH05        950 0.473  142.       420           1020      0.473     142.
#>  6 HH06        920 0.473  142.       420            970      0.473     142.
#>  7 HH07        620 0.473  142.       420            620      0.473     142.
#>  8 HH08        560 0.473  142.       420            545      0.473     142.
#>  9 HH09        770 0.473  142.       420            860      0.473     142.
#> 10 HH10        710 0.473  142.       420            695      0.473     142.
#> 11 HH11        980 0.473  142.       420           1070      0.473     142.
#> 12 HH12       1280 0.473  142.       420           1265      0.473     142.
#> 13 HH13        890 0.473  142.       420            815      0.473     142.
#> 14 HH14        770 0.473  142.       420            860      0.473     142.
#> 15 HH15        950 0.473  142.       420           1020      0.473     142.
#> 16 HH16        920 0.473  142.       420            970      0.473     142.
#> 17 HH17        560 0.473  142.       420            545      0.473     142.
#> 18 HH18        620 0.473  142.       420            620      0.473     142.
#> 19 HH19        920 0.473  142.       420            970      0.473     142.
#> 20 HH20        560 0.473  142.       420            650      0.473     142.
#> # ℹ 1 more variable: roughness_20km <dbl>
```
