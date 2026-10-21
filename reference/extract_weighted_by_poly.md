# Weighted Mean or Mode of Raster Values by Polygon

Summarises each layer of a raster over each polygon, with every cell
counting by the fraction of it inside the polygon times a weight: its
area by default, or a count such as population.

## Usage

``` r
extract_weighted_by_poly(
  raster,
  poly,
  stat = c("mean", "mode"),
  weights = NULL,
  iteration = NULL,
  id = NULL,
  label = NULL
)
```

## Arguments

- raster:

  A `SpatRaster`, one or more layers.

- poly:

  A `SpatVector` or `sf` object of polygons, in the CRS of `raster`.

- stat:

  `"mean"` (default) or `"mode"`.

- weights:

  `NULL` (default) for area weights, or a single-layer `SpatRaster` of
  weights.

- iteration:

  Deprecated; use `label`.

- id:

  Optional name of the column of `poly` identifying the polygons. When
  `NULL`, `ID` or `ID_adm_div` is used when present.

- label:

  Optional name shown in progress messages.

## Value

A `c4e_tbl` carrying the raster's context, with one row per polygon: the
attributes of `poly`, then one column per layer of `raster`, named after
it.

## Details

Each cell counts by \\f_c w_c\\, where \\f_c\\ is the fraction of the
cell inside the polygon
([`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html))
and \\w_c\\ the weight of the cell:

- `weights = NULL`: the cell area in km2. On a lon-lat grid cells shrink
  towards the poles, so area weights differ from a plain average of
  cells.

- `weights` a `SpatRaster`, e.g. population: the polygon value describes
  the conditions where people live rather than the territory. A weight
  raster on another grid is put on the grid of `raster` with
  [`align_count_rast()`](https://jmr-fao.github.io/c4e/reference/align_count_rast.md),
  so it must hold counts.

A polygon whose weights are all zero (no population) falls back to the
coverage fractions alone. Cells where `raster` is `NA` are ignored; a
polygon with no valid cell gets `NA`.

`stat = "mean"` returns the weighted mean, for continuous layers.
`stat = "mode"` returns the class with the largest total weight, for
class layers (land cover, climate zones); ties go to the lowest class.

## See also

[`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md)
for unweighted statistics,
[`align_count_rast()`](https://jmr-fao.github.io/c4e/reference/align_count_rast.md),
[`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html)

## Examples

``` r
r <- terra::rast(xmin = 0, xmax = 2, ymin = 0, ymax = 1, res = 1,
                 crs = "epsg:4326", vals = c(10, 20))
names(r) <- "value"
pop <- terra::rast(r, vals = c(1, 3))
p <- terra::vect(terra::ext(0, 2, 0, 1), crs = "epsg:4326")
p$id <- 1

extract_weighted_by_poly(r, p)                 # area: about 15
#> # A tibble: 1 × 2
#> # Context:  summary
#>      id value
#>   <dbl> <dbl>
#> 1     1    15
extract_weighted_by_poly(r, p, weights = pop)  # people: 17.5
#> # A tibble: 1 × 2
#> # Context:  summary
#>      id value
#>   <dbl> <dbl>
#> 1     1  17.5
```
