# Calculate nearest distance between two SpatVector objects

Computes the minimum distance from each feature in `x` to the nearest
feature in `y`. Returns `x` with an added column containing the nearest
distance in kilometers.

## Usage

``` r
calc_nearest_distance(x, y, return_geometry = FALSE, ...)
```

## Arguments

- x:

  A
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  (polygons, points, or lines).

- y:

  A
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  containing target features.

- return_geometry:

  Logical. If TRUE, returns a `SpatVector` with geometries. If FALSE
  (default), returns a tibble with polygon attributes only.

- ...:

  Additional arguments passed to
  [`terra::nearest()`](https://rspatial.github.io/terra/reference/nearby.html)
  (e.g., `method`, `centroids`, `distance`); giving any uses
  [`terra::nearest()`](https://rspatial.github.io/terra/reference/nearby.html)
  rather than sf.

## Value

Either a
[terra::SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
or a
[tibble::tbl_df](https://tibble.tidyverse.org/reference/tbl_df-class.html)
equal to `x` with an added column:

- `dist_nearest_km`: minimum distance to `y` in kilometers.

## Details

When the sf package is installed and no arguments are passed in `...`,
the nearest feature is found with
[`sf::st_nearest_feature()`](https://r-spatial.github.io/sf/reference/st_nearest_feature.html),
which uses a spatial index, and the distance to it is measured with
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html).
This is much faster on many features and exact: on longitude and
latitude, 500 points to 7,700 road lines take under a second instead of
minutes, and
[`terra::nearest()`](https://rspatial.github.io/terra/reference/nearby.html)
can be tens of per cent off on lines there. Otherwise
[`terra::nearest()`](https://rspatial.github.io/terra/reference/nearby.html)
is used.

If CRS differ, `y` is automatically reprojected to the CRS of `x`.

- Distance is 0 if features intersect.

- If CRS is geographic (lon/lat), consider using `method = "haversine"`.

- For projected CRS (meters), default Euclidean distance is used.

## See also

[terra::nearest](https://rspatial.github.io/terra/reference/nearby.html)
[calc_distance](https://jmr-fao.github.io/c4e/reference/calc_distance.md)

## Examples

``` r
adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
points <- terra::vect(survey, geom = c("lon", "lat"), crs = "EPSG:4326")

# distance from each household to the nearest division border
calc_nearest_distance(points, terra::as.lines(adm_div))
#> # A tibble: 20 × 3
#>    hhid  interview  dist_nearest_km
#>    <chr> <chr>                <dbl>
#>  1 HH01  2023-08-01            8.92
#>  2 HH02  2023-03-17           13.5 
#>  3 HH03  2023-06-19           20.8 
#>  4 HH04  2023-05-30           24.3 
#>  5 HH05  2023-04-16            3.11
#>  6 HH06  2023-03-06           18.6 
#>  7 HH07  2023-06-27            8.92
#>  8 HH08  2023-07-30            6.58
#>  9 HH09  2023-07-16            9.87
#> 10 HH10  2023-08-02           30.4 
#> 11 HH11  2023-04-10            1.06
#> 12 HH12  2023-05-10           16.7 
#> 13 HH13  2023-06-11           24.3 
#> 14 HH14  2023-08-17            9.87
#> 15 HH15  2023-05-05            3.11
#> 16 HH16  2023-06-30           18.6 
#> 17 HH17  2023-04-24            6.58
#> 18 HH18  2023-03-03            8.92
#> 19 HH19  2023-06-06           18.6 
#> 20 HH20  2023-05-05            8.92
```
