# Crop a Raster with a Buffer around a Vector Layer

Crops a `SpatRaster` object using the extent of a `SpatVector` object,
optionally adding a buffer around the vector extent before cropping.

## Usage

``` r
crop_with_buffer(raster, vector, iteration = NULL, buffer = 0, ...)
```

## Arguments

- raster:

  A `SpatRaster` object to be cropped.

- vector:

  A `SpatVector` object used to define the cropping extent.

- iteration:

  optional character to be print before computation. Usually, it is the
  name of the object on which the function is applied. This is useful
  when the function is used inside an apply family function to keep
  track of the iterations.

- buffer:

  A numeric value specifying the buffer used to expand the cropping
  extent, expressed in the map units of `vector`. For a lon-lat layer
  the buffer is in degrees; for a projected layer it is in the units of
  that projection, typically meters. Default is 0 (no buffer).

- ...:

  Additional arguments passed to
  [`terra::crop()`](https://rspatial.github.io/terra/reference/crop.html).

## Value

A cropped `SpatRaster` object based on the buffered extent of the input
vector layer.

## Details

The function computes the bounding box of the input vector and expands
it in all directions by the buffer amount. The raster is then cropped to
this expanded extent.

No reprojection is performed, so `buffer` is always interpreted in the
map units of the data. To buffer by a metric distance on a lon-lat
layer, project `raster` and `vector` to a suitable CRS first, for
example with
[`get_utm_crs()`](https://jmr-fao.github.io/c4e/reference/get_utm_crs.md).

## See also

[terra::crop](https://rspatial.github.io/terra/reference/crop.html)

## Examples

``` r
tmax <- terra::rast(system.file("extdata", "tmax_daily.tif", package = "c4e"))
adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))

# the first division and 10 km around it
crop_with_buffer(tmax[[1]], adm_div[1], buffer = 10000)
#> class       : SpatRaster
#> size        : 6, 6, 1  (nrow, ncol, nlyr)
#> resolution  : 0.2, 0.2  (x, y)
#> extent      : 30, 31.2, -1, 0.2  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source      : tmax_daily.tif
#> name        : 2021-01-01
#> min value   : 288.306152
#> max value   : 299.532776
#> unit        : K
#> time (days) : 2021-01-01
```
