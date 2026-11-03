# Spatial controls for every cell of a raster, in one call

The grid counterpart of
[`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md)
and the normals of
[`time_varying_controls()`](https://jmr-fao.github.io/c4e/reference/time_varying_controls.md):
population density of the surrounding cells, climate normals and other
layers, as one raster.

## Usage

``` r
grid_controls(
  pop = NULL,
  radius_m = c(5000, 10000),
  climate = NULL,
  years = 30,
  stats = c("mean", "sd", "cv"),
  layers = NULL,
  kind = NULL,
  fact = NULL,
  filename = "",
  overwrite = FALSE,
  wopt = list(),
  control = controls_control()
)
```

## Arguments

- pop:

  A population (count) raster with one layer.

- radius_m:

  Radii in metres for the population density.

- climate:

  Optional named list of climate rasters (paths or `SpatRaster`s), e.g.
  `list(pre = chirps)`.

- years:

  Number of years, counted back from the end of each series, for the
  normals.

- stats:

  Statistics of the normals: any of `"mean"`, `"sd"`, `"cv"`, `"min"`,
  `"max"`, `"median"`, `"sum"`.

- layers:

  Optional named list of other single-layer rasters.

- kind:

  Optional named character vector of layer kinds.

- fact:

  Optional aggregation factor for `layers`, as in
  [`terra::aggregate()`](https://rspatial.github.io/terra/reference/aggregate.html).

- filename:

  Optional GeoTIFF to write the result to.

- overwrite:

  Overwrite `filename` when it exists.

- wopt:

  Options for writing, as in
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).

- control:

  Further options, see
  [`controls_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md).

## Value

A `SpatRaster` with one layer per control; with `dry_run`, `NULL`.

## Details

- With `pop`, `pop_density_<r>km` is the population within each radius
  divided by the land area within it (cells where `pop` is missing count
  for neither), in people per square kilometre. A radius of 0 gives the
  cell's own density, `pop_density`. On longitude/latitude rasters the
  circle is measured in kilometres at the raster's mean latitude.

- With `climate`, a named list of rasters, `<name>_<stat>` are the
  statistics over the last `years` years of each series, computed with
  [`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md); a
  coefficient of variation of temperatures is computed on kelvin.

- With `layers`, a named list of single-layer rasters, each is added,
  and aggregated by `fact` when given: averaged, summed or by majority,
  following its kind (see
  [`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md)).

Rasters on different grids are resampled onto the first one (bilinear
for continuous layers, nearest for categorical ones, sums for counts),
with a message.

## See also

[`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md),
[`time_varying_controls()`](https://jmr-fao.github.io/c4e/reference/time_varying_controls.md),
[`grid_indicators()`](https://jmr-fao.github.io/c4e/reference/grid_indicators.md)

## Examples

``` r
template <- terra::rast(system.file("extdata", "tmax_daily.tif",
                                    package = "c4e"))[[1]]
pop <- terra::rast(template, vals = seq(100, 3600, by = 100))
grid_controls(pop = pop, radius_m = c(0, 50000))
#> ℹ grid_controls
#>   population density within 0, 50 km
#> class       : SpatRaster
#> size        : 6, 6, 2  (nrow, ncol, nlyr)
#> resolution  : 0.2, 0.2  (x, y)
#> extent      : 30, 31.2, -1, 0.2  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varnames    : pop (c4e:)
#>               pop (c4e:)
#> names       : pop_density, pop_density_50km
#> min values  :    0.203102,         1.447109
#> max values  :    7.312554,         6.068171
#> unit        : per km2
#> time (days) : 2021-01-01
```
