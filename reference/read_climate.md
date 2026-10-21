# Read a climate raster with its context

Reads one or more raster files and records what later steps need: the
dates of the layers, the variable, its unit, the time step and whether
the values are continuous, counts or categories. Layers are named by
their ISO dates. Explicit arguments always win over what the files say.

## Usage

``` r
read_climate(
  path,
  variable = NULL,
  unit = NULL,
  time_step = NULL,
  kind = NULL,
  source = NULL,
  na_value = NULL,
  label = NULL,
  rotate = TRUE
)
```

## Arguments

- path:

  Path(s) to raster files, or a `SpatRaster`.

- variable:

  Variable name, e.g. `"tmax"` or `"pre"`.

- unit:

  Unit of the values, e.g. `"K"` or `"mm/day"`. This declares the unit;
  to change the values, use
  [`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md).

- time_step:

  One of `"hour"`, `"day"`, `"month"`, `"year"`. Inferred from the dates
  when `NULL`.

- kind:

  One of `"continuous"`, `"count"`, `"categorical"`. Decides how later
  steps aggregate the values (mean, sum, mode). Inferred from the
  variable when `NULL`.

- source:

  Name of a registered source, to skip detection.

- na_value:

  Values to treat as missing, e.g. `128` for URCA.

- label:

  Name used in progress messages and later steps. Defaults to the file
  name.

- rotate:

  When `TRUE`, rotate rasters with longitudes beyond 180.

## Value

A `SpatRaster` with dates, unit and package metadata; see
[`raster_meta()`](https://jmr-fao.github.io/c4e/reference/raster_meta.md).

## Details

Dates come, in order of preference, from the source's convention (ERA5
layer names such as `t2m_valid_time=1704067200`), from the dates stored
in the file, from layer names that are dates, or from dates in the file
names when there is one file per layer (CHIRPS). The variable is taken
from the source or found in the variable and file names, and is
standardised: `t2m` becomes `tmean`, `tp` and `precip` become `pre`. See
[`register_source()`](https://jmr-fao.github.io/c4e/reference/register_source.md)
to add a dataset's conventions.

While reading, codes in `na_value` become `NA`, and a raster with
longitudes from 0 to 360 is rotated to -180 to 180 so it lines up with
survey coordinates.

## See also

[`raster_meta()`](https://jmr-fao.github.io/c4e/reference/raster_meta.md),
[`aggregate_time()`](https://jmr-fao.github.io/c4e/reference/aggregate_time.md),
[`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)

## Examples

``` r
tmax <- read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
raster_meta(tmax)[c("variable", "unit", "time_step")]
#> $variable
#> [1] "tmax"
#> 
#> $unit
#> [1] "K"
#> 
#> $time_step
#> [1] "day"
#> 
```
