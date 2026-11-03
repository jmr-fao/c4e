# Calculate weighted (least-cost) distance to target features

Computes accumulated least-cost distance from target features across a
friction (cost) surface using
[`terra::costDist()`](https://rspatial.github.io/terra/reference/costDist.html).

## Usage

``` r
calc_weighted_distance(target, friction, origin_value = -999, ...)
```

## Arguments

- target:

  A `SpatVector` representing target locations (points, lines, or
  polygons).

- friction:

  A `SpatRaster` representing the cost surface. Values must be positive
  numeric costs.

- origin_value:

  Numeric value used internally to mark origin cells. Default is -999.
  Must not already exist in the friction raster.

- ...:

  additional arguments passed to
  [terra::costDist](https://rspatial.github.io/terra/reference/costDist.html)

## Value

A `SpatRaster` of accumulated least-cost distances.

## See also

[`costDist`](https://rspatial.github.io/terra/reference/costDist.html)

## Examples

``` r
friction <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 20,
                        ymin = 0, ymax = 20, crs = "EPSG:32636")
terra::values(friction) <- 1
target <- terra::vect(matrix(c(10.5, 10.5), ncol = 2), crs = "EPSG:32636")

calc_weighted_distance(target, friction)
#> class       : SpatRaster
#> size        : 20, 20, 1  (nrow, ncol, nlyr)
#> resolution  : 1, 1  (x, y)
#> extent      : 0, 20, 0, 20  (xmin, xmax, ymin, ymax)
#> coord. ref. : WGS 84 / UTM zone 36N (EPSG:32636)
#> source(s)   : memory
#> name        :      last
#> min value   :         0
#> max value   : 13.435029
```
