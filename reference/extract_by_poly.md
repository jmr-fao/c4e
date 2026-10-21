# Extract and Aggregate Raster Values by Polygons

This function extracts raster values within polygon features and
aggregates them using a specified summary function (e.g., "mean", "sum",
"mode"). It returns the extracted values as a `c4e_tbl` carrying the
raster's context.

## Usage

``` r
extract_by_poly(
  raster,
  poly,
  fn_agg = NULL,
  na_rm = TRUE,
  pkg = "terra",
  id = NULL,
  weights = NULL,
  label = NULL
)
```

## Arguments

- raster:

  A `SpatRaster` object from the `terra` package.

- poly:

  A `SpatVector` or `sf` object representing polygon features.

- fn_agg:

  A function or character string specifying how to aggregate raster
  values within each polygon, e.g. `"mean"`, `"sum"`, `"mode"`. Defaults
  from the kind of variable, else `"mean"`.

- na_rm:

  Logical. If `TRUE`, `NA` values in the raster are ignored during
  aggregation. Default is `TRUE`.

- pkg:

  Optional character string. The package to use: `"terra"` or
  `"exactextractr"`. If `NULL`, a package is chosen based on polygon
  count. Default is `"terra"`.

- id:

  Optional name of the column of `poly` identifying the polygons. When
  `NULL`, `ID` or `ID_adm_div` is used when present.

- weights:

  `NULL`, or `"coverage"` to weight each cell by the fraction of it
  inside the polygon (uses `exactextractr`).

- label:

  Optional name shown in progress messages.

## Value

A `c4e_tbl` with the attributes of `poly` and the aggregated raster
values, one row per polygon.

## Details

With `pkg = "terra"`, cells whose centre lies in a polygon count fully.
With `pkg = "exactextractr"`, or `weights = "coverage"`, each cell
counts by the fraction of it inside the polygon, which matters for small
polygons and coarse rasters; the computation runs in C++. For other
weights, such as population, see
[`extract_weighted_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_weighted_by_poly.md).

When `fn_agg` is not given it follows from the kind of variable recorded
by
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md):
the mean for continuous variables, the sum for counts (population) and
the most frequent value for categories. The choice is announced.

The raster and the polygons must share a CRS.

## See also

[`extract`](https://rspatial.github.io/terra/reference/extract.html),
[`exact_extract`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html),
[`extract_weighted_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_weighted_by_poly.md),
[`extract_cell_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_cell_by_poly.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
adm_div <- terra::vect(
  system.file("extdata", "adm_div.gpkg", package = "c4e"))

extract_by_poly(tmax[[1:5]], adm_div)
#> Summarising by polygon with `fn_agg = "mean"`: tmax is a level.
#> # A tibble: 3 × 8
#> # Context:  tmax [K], day, wide; key ID_adm_div
#>   ID_adm_div adm_div_1 adm_div_2  `2021-01-01` `2021-01-02` `2021-01-03`
#>   <chr>      <chr>     <chr>             <dbl>        <dbl>        <dbl>
#> 1 1          West      West A             293.         294.         293.
#> 2 2          East      East South         295.         296.         295.
#> 3 3          East      East North         296.         295.         295.
#> # ℹ 2 more variables: `2021-01-04` <dbl>, `2021-01-05` <dbl>
extract_by_poly(tmax[[1:5]], adm_div, weights = "coverage")
#> Summarising by polygon with `fn_agg = "mean"`: tmax is a level.
#> # A tibble: 3 × 8
#> # Context:  tmax [K], day, wide; key ID_adm_div
#>   ID_adm_div adm_div_1 adm_div_2  `2021-01-01` `2021-01-02` `2021-01-03`
#>   <chr>      <chr>     <chr>             <dbl>        <dbl>        <dbl>
#> 1 1          West      West A             293.         294.         293.
#> 2 2          East      East South         295.         296.         295.
#> 3 3          East      East North         296.         295.         295.
#> # ℹ 2 more variables: `2021-01-04` <dbl>, `2021-01-05` <dbl>
```
