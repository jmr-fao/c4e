# Compute Road Network Density per Polygon

Computes road network density (length per unit area) for each polygon by
intersecting a line road network with polygon geometries.

## Usage

``` r
calc_road_density(polygons, roads, poly_id = NULL, return_geometry = FALSE)
```

## Arguments

- polygons:

  A
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  polygon object.

- roads:

  A
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  line object representing roads.

- poly_id:

  Optional character string specifying the polygon ID column. If NULL,
  the function searches for `"ID"` or `"ID_adm_div"`.

- return_geometry:

  Logical. If TRUE, returns a `SpatVector` with geometries. If FALSE
  (default), returns a tibble with polygon attributes only.

## Value

Either a
[terra::SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
or a
[tibble::tbl_df](https://tibble.tidyverse.org/reference/tbl_df-class.html)
with columns:

- road_length_km:

  Total road length inside each polygon in km

- n_roads:

  Number of road segments intersecting each polygon

- area_km2:

  Polygon area in km²

- road_density:

  Road length per km²

## See also

[terra::intersect](https://rspatial.github.io/terra/reference/intersect.html)
[terra::perim](https://rspatial.github.io/terra/reference/perim.html)

## Examples

``` r
adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
roads <- terra::vect(c("LINESTRING (30 -0.5, 31.2 -0.5)",
                       "LINESTRING (30.6 -1, 30.6 0.2)"), crs = "EPSG:4326")

# a tibble (default)
calc_road_density(adm_div, roads)
#> # A tibble: 3 × 7
#>   ID_adm_div adm_div_1 adm_div_2  road_length_km n_roads area_km2 road_density
#>   <chr>      <chr>     <chr>               <dbl>   <int>    <dbl>        <dbl>
#> 1 1          West      West A              199.        2    8862.       0.0225
#> 2 2          East      East South          133.        2    4431.       0.0300
#> 3 3          East      East North           66.3       1    4431.       0.0150

# a SpatVector with the geometries
calc_road_density(adm_div, roads, return_geometry = TRUE)
#> class       : SpatVector
#> geometry    : polygons
#> dimensions  : 3, 7  (geometries, attributes)
#> extent      : 30, 31.2, -1, 0.2  (xmin, xmax, ymin, ymax)
#> source      : adm_div.gpkg
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> names       : ID_adm_div adm_div_1  adm_div_2 road_length_km n_roads area_km2 road_density
#> type        :      <chr>     <chr>      <chr>          <num>   <int>    <num>        <num>
#> values      :          1      West     West A        199.478       2  8862.25    0.0225088
#>                        2      East East South        133.134       2  4430.97    0.0300462
#>                        3      East East North        66.3446       1  4431.28    0.0149719
```
