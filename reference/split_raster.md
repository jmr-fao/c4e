# Split a Raster into Smaller Tiles

This function divides a `SpatRaster` object into a grid of smaller
tiles, optionally adding overlap between adjacent tiles. It is useful
for parallel processing, memory management, or spatial subsetting of
large rasters.

## Usage

``` r
split_raster(rast, n_x = 10, n_y = 10, overlap = 0)
```

## Arguments

- rast:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  object to be divided.

- n_x:

  Integer. Number of splits (tiles) along the x-axis (longitude).

- n_y:

  Integer. Number of splits (tiles) along the y-axis (latitude).

- overlap:

  Numeric. Optional overlap between adjacent tiles, in map units of the
  raster’s coordinate reference system (e.g., meters or degrees).

## Value

A named list of `SpatRaster` objects, each representing a tile of the
original raster. Tile names follow the pattern `"tile_001"`,
`"tile_002"`, etc.

## Details

The raster is divided evenly along the x and y axes according to `n_x`
and `n_y`. Each resulting tile is cropped from the original raster based
on the computed sub-extent. If `overlap > 0`, each tile is extended by
the specified distance in all directions before cropping, which can be
useful to avoid edge effects in analyses requiring neighborhood
operations.

## Examples

``` r
r <- terra::rast(nrows = 100, ncols = 100, vals = stats::runif(10000))

# a 4 x 4 grid of tiles
tiles <- split_raster(r, n_x = 4, n_y = 4)
length(tiles)
#> [1] 16

# a 2 x 2 grid with tiles overlapping by 10 map units
split_raster(r, n_x = 2, n_y = 2, overlap = 10)[[1]]
#> class       : SpatRaster
#> size        : 56, 53, 1  (nrow, ncol, nlyr)
#> resolution  : 3.6, 1.8  (x, y)
#> extent      : -180, 10.8, -90, 10.8  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (CRS84) (OGC:CRS84)
#> source(s)   : memory
#> name        :    lyr.1
#> min value   : 0.000476
#> max value   :  0.99975
```
