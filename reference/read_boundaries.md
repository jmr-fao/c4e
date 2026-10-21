# Read administrative boundaries

One entry point for the boundary datasets the package knows: FAO GAUL
and geoBoundaries. Both return the same layout, so later steps do not
depend on the source: one row per division, a sequential `ID_adm_div`,
the names `adm_div_1`, `adm_div_2`, ... and the country `iso`.

## Usage

``` r
read_boundaries(
  path,
  iso,
  level = 2,
  source = c("gaul", "geoboundaries"),
  file_format = "geojson"
)
```

## Arguments

- path:

  Folder containing the boundary files, organised as described in
  `read_GAUL()` and `read_geoBoundaries()`.

- iso:

  ISO 3166-1 alpha-3 country code(s).

- level:

  Administrative level, `1` or `2`.

- source:

  `"gaul"` or `"geoboundaries"`.

- file_format:

  File extension of the boundary files.

## Value

A `SpatVector`, or a named list of them when `iso` has several codes.

## Examples

``` r
# a miniature GAUL folder: <root>/<ISO>/<ISO>_ADM2/<ISO>_ADM2.geojson
root <- file.path(tempdir(), "gaul")
dir.create(file.path(root, "MWI", "MWI_ADM2"), recursive = TRUE,
           showWarnings = FALSE)
adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
adm_div$iso3_code <- "MWI"
adm_div$gaul1_name <- c("North", "North", "South")
adm_div$gaul2_name <- c("Alpha", "Beta", "Gamma")
terra::writeVector(adm_div, file.path(root, "MWI", "MWI_ADM2", "MWI_ADM2.geojson"),
                   filetype = "GeoJSON", overwrite = TRUE)

read_boundaries(root, iso = "MWI", level = 2)
#> Warning: [names<-] some names were changed to make them valid and/or unique
#> class       : SpatVector
#> geometry    : polygons
#> dimensions  : 3, 6  (geometries, attributes)
#> extent      : 30, 31.2, -1, 0.2  (xmin, xmax, ymin, ymax)
#> source      : MWI_ADM2.geojson
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> names       : ID_adm_div adm_div_1_1 adm_div_2_1   iso adm_div_1_2 adm_div_2_2
#> type        :      <chr>       <chr>       <chr> <chr>       <chr>       <chr>
#> values      :          1        West      West A   MWI       North       Alpha
#>                        2        East  East South   MWI       North        Beta
#>                        3        East  East North   MWI       South       Gamma
```
