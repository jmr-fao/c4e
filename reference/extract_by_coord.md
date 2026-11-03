# Extract values from a SpatRaster

Extract values from a
[SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
for a set of locations. The locations must be a point
[SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html).

## Usage

``` r
extract_by_coord(
  raster,
  coord,
  iteration = NULL,
  id = NULL,
  buffer = NULL,
  fn = NULL,
  label = NULL,
  chunk = "auto",
  ...
)
```

## Arguments

- raster:

  A
  [SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html).
  Each layer becomes one column of the result.

- coord:

  A point
  [SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  carrying the unit identifier, typically created with
  [`georef_coord()`](https://jmr-fao.github.io/c4e/reference/georef_coord.md).

- iteration:

  Deprecated; use `label`.

- id:

  Optional character string naming the column that identifies the units.
  When `NULL`, `ID` is used, or `ID_adm_div` when that is the only one
  present.

- buffer:

  Optional distance in metres around each location to summarise.

- fn:

  Summary over a buffer: `"mean"`, `"sum"`, `"mode"`, `"min"`, `"max"`
  or a function. Defaults from the kind of variable.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` extracts in blocks of layers only when needed; a whole number
  forces that many layers per block; `FALSE` never splits.

- ...:

  additional arguments to pass to
  [terra::extract](https://rspatial.github.io/terra/reference/extract.html).

## Value

A `c4e_tbl` with the extracted values for each location and the
coordinates of its cell (`x_cell`, `y_cell`). If the raster has multiple
layers, the values of the layer will be split by columns.

## Details

The result is a `c4e_tbl` that carries the raster's context: variable,
unit, time step, dates, CRS and data source, as recorded by
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md).
Later steps read their defaults from it.

The raster and the locations must share a CRS. Locations outside the
raster, or on cells that are missing in every layer, are reported with
their identifiers.

With `buffer`, each location gets a summary of the cells within that
distance instead of the value of its own cell: the mean for continuous
variables, the sum for counts (population) and the most frequent value
for categories, unless `fn` says otherwise.

When the result would exceed the memory budget (see
[`?c4e`](https://jmr-fao.github.io/c4e/reference/c4e-package.md)), the
layers are extracted in blocks and bound together, with a progress bar.

## See also

[`extract`](https://rspatial.github.io/terra/reference/extract.html),
[`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md),
[`extract_cell_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_cell_by_poly.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
survey <- read.csv(
  system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
points <- georef_coord(coord, geom = c("lon", "lat"), crs = "EPSG:4326")

extract_by_coord(tmax[[1:5]], points)
#> # A tibble: 12 × 8
#> # Context:  tmax [K], day, wide; key ID
#>    ID          x_cell y_cell `2021-01-01` `2021-01-02` `2021-01-03` `2021-01-04`
#>    <chr>        <dbl>  <dbl>        <dbl>        <dbl>        <dbl>        <dbl>
#>  1 30.87620_-…   30.9   -0.9         296.         298.         296.         299.
#>  2 30.45000_-…   30.5   -0.7         295.         292.         292.         293.
#>  3 30.85840_-…   30.9   -0.3         295.         296.         298.         295.
#>  4 30.77090_-…   30.7   -0.3         294.         295.         299.         297.
#>  5 30.43250_-…   30.5   -0.3         292.         294.         294.         293.
#>  6 30.41290_-…   30.5   -0.3         292.         294.         294.         293.
#>  7 30.38170_-…   30.3   -0.3         293.         293.         296.         294.
#>  8 30.68870_-…   30.7   -0.1         293.         294.         295.         295.
#>  9 30.27330_-…   30.3   -0.1         293.         295.         294.         292.
#> 10 30.51990_0…   30.5    0.1         290.         296.         293.         290.
#> 11 30.89740_0…   30.9    0.1         295.         294.         293.         293.
#> 12 30.41520_0…   30.5    0.1         290.         296.         293.         290.
#> # ℹ 1 more variable: `2021-01-05` <dbl>

# the mean of the cells within 20 km of each location
extract_by_coord(tmax[[1:5]], points, buffer = 20000)
#> # A tibble: 12 × 6
#> # Context:  tmax [K], day, wide; key ID
#>    ID           `2021-01-01` `2021-01-02` `2021-01-03` `2021-01-04` `2021-01-05`
#>    <chr>               <dbl>        <dbl>        <dbl>        <dbl>        <dbl>
#>  1 30.87620_-0…         295.         296.         295.         296.         297.
#>  2 30.45000_-0…         294.         293.         294.         294.         296.
#>  3 30.85840_-0…         295.         295.         297.         294.         294.
#>  4 30.77090_-0…         295.         295.         297.         295.         294.
#>  5 30.43250_-0…         293.         294.         295.         294.         293.
#>  6 30.41290_-0…         292.         294.         295.         293.         292.
#>  7 30.38170_-0…         293.         295.         294.         293.         293.
#>  8 30.68870_-0…         293.         295.         297.         296.         295.
#>  9 30.27330_-0…         293.         294.         292.         293.         294.
#> 10 30.51990_0.…         293.         296.         293.         292.         292.
#> 11 30.89740_0.…         295.         294.         293.         293.         296.
#> 12 30.41520_0.…         292.         294.         293.         293.         292.
```
