# Fill Missing Raster Values Using Neighboring Cells

Applies a moving window operation that replaces only the missing values
(`NA`) in a raster with an aggregate of their surrounding cells.

## Usage

``` r
fill_missing_rast(raster, w = 3, fun = "mean", shape = "square")
```

## Arguments

- raster:

  A `SpatRaster` object from the **terra** package.

- w:

  Integer or matrix. The size of the moving window (default = 3). If
  `shape = "square"`, the window will be of size `w x w`. If
  `shape = "circle"`, `w` defines the radius of the circular window.

- fun:

  Function or character. The function to apply to neighboring values.
  Common choices include `"mean"` (default), `"median"`, `"min"`,
  `"max"`, or a user-supplied function.

- shape:

  Character. The shape of the moving window. Options are `"square"`
  (default) or `"circle"`.

## Value

A `SpatRaster` with missing values replaced by the aggregated
neighboring values.

## Details

Only cells with missing values (`NA`) are replaced; all other cells
remain unchanged. The replacement value is computed using the specified
function applied over the defined window of neighboring cells.

## See also

[terra::focal](https://rspatial.github.io/terra/reference/focal.html)

## Examples

``` r
r <- terra::rast(nrows = 10, ncols = 10, vals = seq_len(100))
r[c(12, 45, 78)] <- NA
filled <- fill_missing_rast(r, w = 3, fun = "mean")
terra::values(filled)[c(12, 45, 78)]
#> [1] 12 45 78
```
