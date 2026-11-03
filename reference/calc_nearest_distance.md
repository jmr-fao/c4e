# Calculate nearest distance between two SpatVector objects

Computes the minimum distance from each feature in `x` to the nearest
feature in `y` using
[`terra::nearest()`](https://rspatial.github.io/terra/reference/nearby.html).
Returns `x` with an added column containing the nearest distance in
kilometers.

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
  (e.g., `method`, `centroids`, `distance`).

## Value

Either a
[terra::SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
or a
[tibble::tbl_df](https://tibble.tidyverse.org/reference/tbl_df-class.html)
equal to `x` with an added column:

- `dist_nearest_km`: minimum distance to `y` in kilometers.

## Details

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
#>  2 HH02  2023-03-17           13.4 
#>  3 HH03  2023-06-19           20.8 
#>  4 HH04  2023-05-30           24.3 
#>  5 HH05  2023-04-16            3.09
#>  6 HH06  2023-03-06           18.6 
#>  7 HH07  2023-06-27            8.86
#>  8 HH08  2023-07-30            6.55
#>  9 HH09  2023-07-16            9.88
#> 10 HH10  2023-08-02           30.4 
#> 11 HH11  2023-04-10            1.05
#> 12 HH12  2023-05-10           16.7 
#> 13 HH13  2023-06-11           24.3 
#> 14 HH14  2023-08-17            9.88
#> 15 HH15  2023-05-05            3.09
#> 16 HH16  2023-06-30           18.6 
#> 17 HH17  2023-04-24            6.55
#> 18 HH18  2023-03-03            8.86
#> 19 HH19  2023-06-06           18.6 
#> 20 HH20  2023-05-05            8.92
```
