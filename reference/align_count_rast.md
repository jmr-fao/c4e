# Align a Count Raster onto the Grid of Another Raster

Resamples a raster of counts (people, livestock heads) onto the grid of
`template` so that it can serve as extraction weights for `template`,
for example with
[`extract_weighted_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_weighted_by_poly.md).

## Usage

``` r
align_count_rast(count, template, tolerance = 0.01, iteration = NULL)
```

## Arguments

- count:

  A `SpatRaster` of counts, in the same CRS as `template`.

- template:

  A `SpatRaster` whose grid the counts are put on.

- tolerance:

  Relative margin below which the two resolutions are treated as equal.
  Default `0.01`.

- iteration:

  optional character to be print before computation. Usually, it is the
  name of the object on which the function is applied. This is useful
  when the function is used inside an apply family function to keep
  track of the iterations.

## Value

A `SpatRaster` on the grid of `template`, with no `NA`.

## Details

A count cannot be interpolated like a continuous value. The method
follows the resolutions:

- `template` coarser than `count`: the counts are summed into each
  template cell, so totals are preserved. When the grids nest (the
  resolution ratio is a whole number and the cell edges line up, e.g. 30
  arc-seconds into 5 arc-minutes) the sum is exact, with
  [`terra::aggregate()`](https://rspatial.github.io/terra/reference/aggregate.html);
  otherwise
  [`terra::resample()`](https://rspatial.github.io/terra/reference/resample.html)
  with `method = "sum"` shares each count by overlap.

- `template` as fine as or finer than `count`: each template cell takes
  the count of the cell it falls in (`method = "near"`). Totals are not
  preserved, but the relative weights between cells are, which is what a
  weighting needs.

`NA` counts are set to 0. Weights must have no `NA`, because
[`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html)
returns `NaN` for a polygon when any of its weight cells is `NA`.

## See also

[`extract_weighted_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_weighted_by_poly.md),
[`terra::resample()`](https://rspatial.github.io/terra/reference/resample.html)

## Examples

``` r
pop <- terra::rast(xmin = 0, xmax = 1, ymin = 0, ymax = 1, res = 0.1,
                   crs = "epsg:4326", vals = 1)
coarse <- terra::rast(xmin = 0, xmax = 1, ymin = 0, ymax = 1, res = 0.5,
                      crs = "epsg:4326", vals = 0)
align_count_rast(pop, coarse) # 25 people in each coarse cell
#> class       : SpatRaster
#> size        : 2, 2, 1  (nrow, ncol, nlyr)
#> resolution  : 0.5, 0.5  (x, y)
#> extent      : 0, 1, 0, 1  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> name        : lyr.1
#> min value   :    25
#> max value   :    25
```
