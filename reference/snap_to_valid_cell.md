# Move points off the empty cells of a grid

Finds the locations that fall in a cell with no value and moves each to
the centre of the nearest cell that has one, within `radius_deg`,
leaving every other location untouched. Intended for land-only grids —
ERA5-Land is a land model on a 0.1 degree grid, GloFAS stops at the
coast — where a household on land can sit in an empty cell.

## Usage

``` r
snap_to_valid_cell(
  x,
  raster,
  radius_deg = 0.25,
  lat = lat,
  lon = lon,
  layer = 1
)
```

## Arguments

- x:

  A data frame with coordinate columns, or a table from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- raster:

  A `SpatRaster`, or a file path. Only `layer` is looked at: the cells a
  land mask leaves empty are the same on every date.

- radius_deg:

  How far a point may be moved, in degrees, converted at 111 320 m per
  degree. The default 0.25 is two and a half cells of the 0.1 degree
  ERA5-Land grid.

- lat, lon:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Coordinate columns; `lat` and `lon` by default.

- layer:

  Which layer to read the empty cells from.

## Value

`x` with the coordinates of the moved points replaced, and a `snapped`
column: `TRUE` where the point was moved, `FALSE` where it was already
in a cell with a value or no cell was near enough. The original
coordinates are kept in `lat_given` and `lon_given`.

## Details

Nearest rather than interpolated, and bounded, so a moved point reads
one real neighbouring cell's value and cannot take one from across the
country. A location further than `radius_deg` from any cell with a value
is left where it is, and reads `NA`: the usual reason is that it is
genuinely offshore.

[`fill_missing_rast()`](https://jmr-fao.github.io/c4e/reference/fill_missing_rast.md)
does the same job on the raster, by a focal mean over the neighbours
rather than by taking one of them. Prefer that when the raster is the
thing to keep, and this when the points are: filling a forty-year daily
stack to change the value of a handful of locations interpolates some
fifteen thousand layers to no purpose.

## See also

[`fill_missing_rast()`](https://jmr-fao.github.io/c4e/reference/fill_missing_rast.md),
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pre <- read_climate(files, variable = "pre")
places |>
    snap_to_valid_cell(pre) |>
    prepare_coord(lat, lon, id = place)
} # }
```
