# Erase Large Water Bodies from Polygons

Removes sea and lakes from polygons using a land/water mask, so that
statistics of the territory (elevation, cropland, emissions per km2) are
not diluted by water in shoreline or lake units.

## Usage

``` r
erase_water_bodies(
  poly,
  water,
  land_value = 100,
  min_km2 = 50,
  buffer = 0.5,
  iteration = NULL
)
```

## Arguments

- poly:

  A `SpatVector` of polygons.

- water:

  A `SpatRaster` land/water mask, in the CRS of `poly`.

- land_value:

  Value of land cells in `water`; every other non-`NA` value is water.
  Default `100`, as in GSHHS.

- min_km2:

  Smallest water body erased, km2. Default `50`.

- buffer:

  Buffer around `poly` when cropping `water`, in the map units of
  `poly`. Default `0.5`.

- iteration:

  optional character to be print before computation. Usually, it is the
  name of the object on which the function is applied. This is useful
  when the function is used inside an apply family function to keep
  track of the iterations.

## Value

`poly` with the water bodies erased, attributes kept.

## Details

The mask is cropped around the polygons, every cell that is not
`land_value` is turned into water polygons, and the water polygons of at
least `min_km2` are erased. Smaller patches stay part of the units: a
coarse mask only resolves large lakes anyway, and this drops single-cell
noise.

With the GSHHS land/water mask of the spatial repository
(`geophysical/land_water_mask/GSHHS`, ~3 km), land is 100 and water 0.
At that resolution the mask can cut a few km off a coastline, so a very
small coastal unit can lose much of its area.

A polygon entirely under water disappears from the result. Compare the
row counts, or match on an id, to find it.

## See also

[`terra::erase()`](https://rspatial.github.io/terra/reference/erase.html),
[`crop_with_buffer()`](https://jmr-fao.github.io/c4e/reference/crop_with_buffer.md)

## Examples

``` r
water <- terra::rast(xmin = 0, xmax = 2, ymin = 0, ymax = 2, res = 0.5,
                     crs = "epsg:4326", vals = 100)
water[1:2, 1:2] <- 0  # a water body in the top-left corner
p <- terra::vect(terra::ext(0, 2, 0, 2), crs = "epsg:4326")

terra::expanse(p, unit = "km")
#> [1] 49231.58
terra::expanse(erase_water_bodies(p, water), unit = "km")
#> [1] 36922.69
```
