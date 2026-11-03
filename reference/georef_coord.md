# Georeference based on coordinates and coordinate reference system

Turns the distinct locations of a survey into a point
[SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html),
one point per location ID, ready for `extract_*()`.

## Usage

``` r
georef_coord(df, geom = NULL, crs = NULL, id = NULL)
```

## Arguments

- df:

  A data frame, typically from
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- geom:

  character. The field names with the x and y coordinates of the points.
  Defaults to the columns recorded by
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md).

- crs:

  character. The coordinate reference system in one of the following
  formats: WKT/WKT2,
  :`, or PROJ-string notation. See `[`crs`](https://rspatial.github.io/terra/reference/crs.html)`. Defaults to the recorded CRS, else ``"EPSG:4326"``.`

- id:

  Optional character string naming the column that identifies the units.
  When `NULL`, the recorded key, `ID`, or `ID_adm_div` is used.

## Value

A
[SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
of points with one variable, the location identifier.

## Details

After
[`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md),
the coordinate columns are known and `geom` can be left out. Without a
`crs`, the coordinates are taken as longitude and latitude on WGS 84
(`"EPSG:4326"`), which is announced.

## See also

[terra::vect](https://rspatial.github.io/terra/reference/vect.html)

## Examples

``` r
survey <- read.csv(
  system.file("extdata", "survey.csv", package = "c4e"))
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon)
georef_coord(coord)
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
#> class       : SpatVector
#> geometry    : points
#> dimensions  : 12, 1  (geometries, attributes)
#> extent      : 30.2733, 30.8974, -0.8786, 0.1409  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> names       :                ID
#> type        :             <chr>
#> values      : 30.87620_-0.87860
#>               30.45000_-0.70280
#>               30.85840_-0.39050
#>               ...
```
