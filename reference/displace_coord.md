# Displace survey coordinates to protect respondents

Moves every survey location in a random direction by a random distance,
following the rule of the Demographic and Health Surveys (DHS): urban
locations by up to 2 km, rural ones by up to 5 km, and a random 1% of
the rural ones by up to 10 km. Households that share a location move
together.

## Usage

``` r
displace_coord(
  x,
  lat = NULL,
  lon = NULL,
  type = NULL,
  urban = 2000,
  rural = 5000,
  rural_far = 10000,
  share_far = 0.01,
  boundaries = NULL,
  water = NULL,
  min_water_area = 0,
  population = NULL,
  min_people = NULL,
  min_scale = 1,
  max_scale = 3,
  seed = NULL,
  max_tries = 100
)
```

## Arguments

- x:

  A survey from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md),
  or a data frame with coordinates in longitude and latitude (WGS84).

- lat, lon:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  The coordinate columns; read from `x` when it comes from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- type:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional column saying whether each location is `"urban"` or `"rural"`
  (also `"U"`, `"R"`, `TRUE` for urban). When not given, every location
  is treated as rural, the larger displacement.

- urban, rural, rural_far:

  Maximum displacement in metres.

- share_far:

  Share of rural locations displaced by up to `rural_far`.

- boundaries:

  Optional administrative divisions (`SpatVector` of polygons) a
  location must stay inside.

- water:

  Optional water bodies (`SpatVector` of polygons, such as lakes and
  reservoirs) a location must not land in.

- min_water_area:

  Smallest water body kept from `water`, in km2.

- population:

  Optional raster of people per cell (`SpatRaster` or a path), such as
  WorldPop counts. Requires `min_people`.

- min_people:

  Number of people that must live within the limit of each location.

- min_scale, max_scale:

  With `population`, the smallest and largest limit, as multiples of the
  DHS limit of each location.

- seed:

  Optional seed, for a displacement that can be repeated. Keep it
  private.

- max_tries:

  Draws allowed per location to land in its allowed area.

## Value

`x` with displaced coordinates, as a `c4e_tbl`.

## Details

Run it before sharing a file with coordinates, or before any variable is
computed from them when the team itself should not hold the true
locations. Variables computed afterwards (weather extremes, distances,
controls) are then based on the displaced locations: the error this adds
is small for smooth climate fields and division averages, and larger for
short distances such as to the nearest road.

## Where a location may land

Three options restrict or adapt the displacement, alone or together:

- `boundaries`: a location stays inside the administrative division it
  started in, so division-level variables are not affected.

- `water`: a location never lands in a water body, where no household
  lives and where extracted values (temperature over a lake, distance to
  the shore) would be wrong. This costs no privacy, since nobody lives
  there anyway. Use `min_water_area` to keep only large water bodies.

- `population` and `min_people`: the limit of each location becomes the
  radius within which at least `min_people` people live (inside its
  division and outside water, when those are given), between `min_scale`
  and `max_scale` times its DHS limit. Sparse places then move further
  and dense ones less, so every respondent hides among about the same
  number of people. With the default `min_scale = 1` the DHS limits are
  a floor, as many data agreements require; a smaller `min_scale` lets
  dense places move less than the DHS rule. A location that reaches
  `max_scale` holds fewer people than asked, and a warning says how
  many.

## What changes in the table

- The coordinate columns hold the displaced coordinates.

- Location identifiers built from coordinates
  ([`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md)
  with `id_rule = "coordinates"`) are rebuilt from the displaced ones,
  since the old identifiers would reveal the true locations.

- The context records the rule, the limits and the options used (not the
  seed). Labels, the Stata codebook and printed tables then say that the
  coordinates are displaced, and later tables built from these locations
  carry the record.

Keep `seed` private: with the seed, the displacement can be undone.

## See also

[`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md)

## Examples

``` r
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon, id = hhid)

adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
displaced <- displace_coord(coord, boundaries = adm_div, seed = 1)
#> No `type` given: every location is displaced as rural (up to 5 km).

# how far each location moved, in km
moved <- terra::distance(as.matrix(coord[c("lon", "lat")]),
                         as.matrix(displaced[c("lon", "lat")]),
                         lonlat = TRUE, pairwise = TRUE) / 1000
summary(moved)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.6269  1.8889  2.8668  2.7001  3.5859  4.9381 
c4e_labels(displaced)
#>                                             lon 
#> "longitude, displaced up to 5/10 km (DHS rule)" 
#>                                             lat 
#>  "latitude, displaced up to 5/10 km (DHS rule)" 

# a lake to avoid, and a radius holding at least 5,000 people
lake <- terra::buffer(terra::vect(cbind(30.6, -0.4), crs = "EPSG:4326"), 8000)
people <- terra::rast(adm_div, resolution = 0.01)
terra::values(people) <- 50 * terra::values(terra::cellSize(people, unit = "km"))
displaced <- displace_coord(coord, boundaries = adm_div, water = lake,
                            population = people, min_people = 5000, seed = 1)
#> No `type` given: every location is displaced as rural (up to 5 km).
#> Finding the radius that holds 5000 people for 12 locations.
```
