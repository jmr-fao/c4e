# Compute Distances Between Spatial Objects (using purrr::partial)

Computes distances from each feature in `x` to features in `y`.
Optionally reduces multiple distances per feature using a summary
function.

## Usage

``` r
calc_distance(
  x,
  y,
  fun_summ = min,
  fun_args = list(),
  use_union = TRUE,
  return_geometry = FALSE,
  ...
)
```

## Arguments

- x:

  A
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  (points, lines, or polygons) for which distances will be computed.

- y:

  A
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  containing target features.

- fun_summ:

  Optional summary function (e.g., `min`, `max`, `mean`). If provided,
  reduces distances per feature in `x` to a single value. Default is
  `min`. If `NULL`, the full distance matrix is returned.

- fun_args:

  Optional list of additional arguments to pass to `fun_summ`.

- use_union:

  Logical. If TRUE (default) and `fun_summ` is not NULL, `y` will be
  unioned to simplify geometry before computing distances. Union can
  improve performance for large overlapping features

- return_geometry:

  Logical. If TRUE, returns a `SpatVector` with geometries. If FALSE
  (default), returns a tibble with polygon attributes only.

- ...:

  Additional arguments passed to
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
  (e.g., `method = "haversine"`).

## Value

If `fun_summ` is provided, returns either a
[terra::SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
or a
[tibble::tbl_df](https://tibble.tidyverse.org/reference/tbl_df-class.html)
with the attributes of `x` plus a `distance` column (in km). If
`fun_summ` is NULL, returns a numeric distance matrix where rows
correspond to features in `x` and columns to features in `y`.

## See also

[terra::distance](https://rspatial.github.io/terra/reference/distance.html)
[`calc_nearest_distance()`](https://jmr-fao.github.io/c4e/reference/calc_nearest_distance.md)
