# Extract Raster Values by Polygon

This function extracts the values of every raster cell within each
polygon, with the fraction of the cell inside the polygon, using the
`exactextractr` package on the `terra` raster directly.

## Usage

``` r
extract_cell_by_poly(
  raster,
  poly,
  id = NULL,
  label = NULL,
  chunk = "auto",
  ...
)
```

## Arguments

- raster:

  A `SpatRaster` representing the raster data to extract.

- poly:

  A `SpatVector` or `sf` object representing the polygon(s) for
  extraction.

- id:

  Optional name of the column of `poly` identifying the polygons. The
  result's identifier column takes this name. Default `ID_adm_div`.

- label:

  Optional name shown in progress messages.

- chunk:

  `"auto"` extracts in blocks of layers only when needed; a whole number
  forces that many layers per block; `FALSE` never splits.

- ...:

  additional arguments to pass to
  [exactextractr::exact_extract](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html).

## Value

A `c4e_tbl` with the polygon identifier, the cell coordinates (`x_cell`,
`y_cell`), the `coverage_fraction` and one column per layer.

## Details

Each cell is identified by the polygon it belongs to and its centre. The
polygon identifier is the polygon's own `ID_adm_div` (or the column
named by `id`) when it has one, else its row number. The result is a
`c4e_tbl` carrying the raster's context, ready for cell-level indicators
that are later aggregated with the coverage fractions.

When the result would exceed the memory budget (see
[`?c4e`](https://jmr-fao.github.io/c4e/reference/c4e-package.md)), the
layers are extracted in blocks and bound together.

## See also

[`exact_extract`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html),
[`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
adm_div <- terra::vect(
  system.file("extdata", "adm_div.gpkg", package = "c4e"))

# one row per cell and division, with the share of the cell inside it
extract_cell_by_poly(tmax[[1:3]], adm_div)
#> # A tibble: 39 × 7
#> # Context:  tmax [K], day, wide; key ID_adm_div
#>    ID_adm_div x_cell y_cell coverage_fraction `2021-01-01` `2021-01-02`
#>    <chr>       <dbl>  <dbl>             <dbl>        <dbl>        <dbl>
#>  1 1            30.1    0.1                 1         292.         293.
#>  2 1            30.3    0.1                 1         294.         291.
#>  3 1            30.5    0.1                 1         290.         296.
#>  4 1            30.1   -0.1                 1         294.         294.
#>  5 1            30.3   -0.1                 1         293.         295.
#>  6 1            30.5   -0.1                 1         296.         296.
#>  7 1            30.1   -0.3                 1         288.         296.
#>  8 1            30.3   -0.3                 1         293.         293.
#>  9 1            30.5   -0.3                 1         292.         294.
#> 10 1            30.1   -0.5                 1         296.         293.
#> # ℹ 29 more rows
#> # ℹ 1 more variable: `2021-01-03` <dbl>
```
