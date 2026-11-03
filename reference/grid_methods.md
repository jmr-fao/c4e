# Indicators for every cell of a raster

The step functions also take a `SpatRaster`: they then compute, for
every cell, what they compute for an extracted location, and return a
raster. The raster is read in blocks of rows, so stacks larger than
memory can be processed, and each block goes through the same code as
extracted data: a cell's numbers are those of the table path at that
cell.

## Usage

``` r
# S3 method for class 'SpatRaster'
calc_threshold_day(
  x,
  above = NULL,
  below = NULL,
  unit = NULL,
  period = c("year", "month"),
  min_coverage = 0.8,
  filename = "",
  overwrite = FALSE,
  wopt = list(),
  ...
)

# S3 method for class 'SpatRaster'
calc_percentile(
  x,
  p,
  exclude_below = NULL,
  exclude_above = NULL,
  yearly = FALSE,
  baseline = NULL,
  replace = NA_real_,
  filename = "",
  overwrite = FALSE,
  wopt = list(),
  ...
)

# S3 method for class 'SpatRaster'
calc_par(
  x,
  fn,
  period = NULL,
  min_coverage = 0.8,
  prefix = NULL,
  suffix = NULL,
  filename = "",
  overwrite = FALSE,
  wopt = list(),
  ...
)

# S3 method for class 'SpatRaster'
calc_std_index(
  x,
  scale,
  index = c("spi", "spei"),
  pet = NULL,
  .parallel = FALSE,
  filename = "",
  overwrite = FALSE,
  wopt = list(),
  ...
)
```

## Arguments

- x:

  A `SpatRaster` of daily (or, for
  [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md),
  monthly) data with dates, ideally from
  [`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md).

- above, below, unit, p, exclude_below, exclude_above, yearly, baseline,
  replace, fn, prefix, suffix, scale, index:

  As for tables.

- period:

  For
  [`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md):
  `"year"` or `"month"`, the periods counted. For
  [`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md):
  as for tables.

- min_coverage:

  Share of a period's days that must have data.

- filename:

  Optional GeoTIFF to write the result to.

- overwrite:

  Overwrite `filename` when it exists.

- wopt:

  Options for writing, as in
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html),
  e.g. `list(datatype = "FLT4S", gdal = "COMPRESS=DEFLATE")`.

- ...:

  Not used.

- pet:

  For
  [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md):
  a raster of potential evapotranspiration with the same geometry, for
  the SPEI.

- .parallel:

  As for tables.

## Value

A `SpatRaster`, one layer per indicator (and period, month or date).

## Details

- [`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)
  counts, per `period` (year or month), the days beyond each threshold
  and sums their excess: layers such as `day_abv_30_sum_2021`.

- [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
  gives each cell's percentiles by calendar month: layers such as
  `day_90p_07`.

- [`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md)
  gives each cell's statistics: layers such as `tmax_mean`.

- [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md)
  gives the monthly SPI or SPEI: layers such as `spi_3_2021-07`.

The result carries its dates, units and the indicator registry in tags
that survive writing a GeoTIFF;
[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
and
[`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md)
turn the extracted values back into the table the table path gives, with
its registry. For spells, percentile-based days and heatwaves on a grid,
use
[`grid_indicators()`](https://jmr-fao.github.io/c4e/reference/grid_indicators.md).

## See also

[`grid_indicators()`](https://jmr-fao.github.io/c4e/reference/grid_indicators.md),
[`grid_controls()`](https://jmr-fao.github.io/c4e/reference/grid_controls.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
hot <- calc_threshold_day(convert_unit(tmax, "C"), above = 30)
hot
#> class       : SpatRaster
#> size        : 6, 6, 6  (nrow, ncol, nlyr)
#> resolution  : 0.2, 0.2  (x, y)
#> extent      : 30, 31.2, -1, 0.2  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varnames    : tmax (c4e:variable=tmax;source=synthetic;label=tmax_daily;time_step=year)
#>               tmax (c4e:variable=tmax;source=synthetic;label=tmax_daily;time_step=year)
#> names       : day_a~_2021, day_a~_2022, day_a~_2023, C_abv~_2021, C_abv~_2022, C_abv~_2023
#> min values  :          65,          71,          68,  111.852008,  128.858972,  111.859369
#> max values  :         151,         153,         151,  500.295221,  500.155884,  521.408496
#> unit        :        days,        days,        days,           C,           C,           C
#> time (days) : 2021-01-01 to 2023-01-01 (3 steps)
```
