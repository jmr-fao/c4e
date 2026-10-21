# Get UTM CRS for a SpatVector (averaging centroids if multiple features)

Computes the appropriate UTM coordinate reference system (CRS) based on
the average centroid coordinates of the input `SpatVector`. Assumes the
input vector is in geographic coordinates (longitude/latitude).

## Usage

``` r
get_utm_crs(vector)
```

## Arguments

- vector:

  A `SpatVector` object with geographic coordinates (lon-lat).

## Value

A [`terra::crs`](https://rspatial.github.io/terra/reference/crs.html)
object representing the UTM zone for the averaged centroid.

## Details

The function calculates the average longitude and latitude of all
feature centroids, determines the UTM zone and hemisphere, and returns a
[`terra::crs`](https://rspatial.github.io/terra/reference/crs.html)
object corresponding to the WGS84 UTM projection.

## Examples

``` r
adm_div <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
get_utm_crs(adm_div)
#> [1] "PROJCRS[\"unknown\",\n    BASEGEOGCRS[\"unknown\",\n        DATUM[\"World Geodetic System 1984\",\n            ELLIPSOID[\"WGS 84\",6378137,298.257223563,\n                LENGTHUNIT[\"metre\",1]],\n            ID[\"EPSG\",6326]],\n        PRIMEM[\"Greenwich\",0,\n            ANGLEUNIT[\"degree\",0.0174532925199433],\n            ID[\"EPSG\",8901]]],\n    CONVERSION[\"UTM zone 36S\",\n        METHOD[\"Transverse Mercator\",\n            ID[\"EPSG\",9807]],\n        PARAMETER[\"Latitude of natural origin\",0,\n            ANGLEUNIT[\"degree\",0.0174532925199433],\n            ID[\"EPSG\",8801]],\n        PARAMETER[\"Longitude of natural origin\",33,\n            ANGLEUNIT[\"degree\",0.0174532925199433],\n            ID[\"EPSG\",8802]],\n        PARAMETER[\"Scale factor at natural origin\",0.9996,\n            SCALEUNIT[\"unity\",1],\n            ID[\"EPSG\",8805]],\n        PARAMETER[\"False easting\",500000,\n            LENGTHUNIT[\"metre\",1],\n            ID[\"EPSG\",8806]],\n        PARAMETER[\"False northing\",10000000,\n            LENGTHUNIT[\"metre\",1],\n            ID[\"EPSG\",8807]],\n        ID[\"EPSG\",17036]],\n    CS[Cartesian,2],\n        AXIS[\"(E)\",east,\n            ORDER[1],\n            LENGTHUNIT[\"metre\",1,\n                ID[\"EPSG\",9001]]],\n        AXIS[\"(N)\",north,\n            ORDER[2],\n            LENGTHUNIT[\"metre\",1,\n                ID[\"EPSG\",9001]]]]"
```
