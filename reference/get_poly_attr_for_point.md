# Extract Polygon Attributes for Point Locations

This function intersects point coordinates with a polygon layer and
returns polygon attributes for each point. If a point falls outside all
polygons, the function assigns attributes from the nearest polygon.

## Usage

``` r
get_poly_attr_for_point(
  point,
  poly,
  iteration = NULL,
  geom = c("lon", "lat"),
  crs = "epsg:4326",
  outside = TRUE
)
```

## Arguments

- point:

  A data frame or `SpatVector` of point features. If a data frame, it
  must contain columns for longitude and latitude specified in `geom`.

- poly:

  A `SpatVector` object representing polygons with attributes to
  extract.

- iteration:

  Optional. A label (e.g., an ID or name) printed during execution to
  indicate which subset is being processed. Useful when running the
  function in a loop or batch.

- geom:

  A character vector of length two specifying the names of the longitude
  and latitude columns (default is `c("lon", "lat")`).

- crs:

  A character string specifying the CRS of the input coordinates
  (default is `"epsg:4326"`).

- outside:

  Logical. If `TRUE` (default), points falling outside every polygon are
  assigned the attributes of the nearest polygon. If `FALSE`, they are
  dropped.

## Value

A tibble containing the original point data and the corresponding
polygon attributes. For points outside all polygons, attributes are
taken from the nearest polygon.

## Details

The function performs an exact spatial intersection. If no intersection
is found, it finds the nearest polygon with
[`terra::nearest()`](https://rspatial.github.io/terra/reference/nearby.html)
and merges its attributes.
