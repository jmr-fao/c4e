# Growing-season bounds at each survey location

Attaches a start and end of season to a survey, ready for
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md).
The bounds come from a published crop calendar in the spatial repository
rather than from the survey, so nothing has to be prepared by hand.

## Usage

``` r
read_season(
  survey,
  source = c("asis", "gaez"),
  season = 1,
  land_cover = c("cropland", "pasture"),
  lat = lat,
  lon = lon,
  path = NULL
)
```

## Arguments

- survey:

  A data frame with coordinate columns.

- source:

  `"asis"` or `"gaez"`, see above.

- season:

  `1` or `2`. Only ASIS has a second season.

- land_cover:

  For ASIS, `"cropland"` or `"pasture"`.

- lat, lon:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Coordinate columns; `lat` and `lon` by default.

- path:

  The dataset folder, if it is not in the spatial repository found by
  [`find_nested_folder()`](https://jmr-fao.github.io/c4e/reference/find_nested_folder.md).

## Value

`survey` with `sos` and `eos` columns added, and `mos` for ASIS. The
unit is stored in the `"season_unit"` attribute.

## Details

Two sources, both long-run averages and so fixed from year to year:

- `"asis"`: FAO ASIS crop and pasture phenology, 1 km, derived from each
  pixel's long-term average NDVI profile. Carries a **second season**
  (`season = 2`), and is masked to cropland or pasture, so locations
  outside the mask come back missing. Bounds are in **dekads**, so pass
  `unit = "dekad"` to
  [`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md).

- `"gaez"`: the GAEZ v5 agro-climatic growing period, about 9 km, from a
  water balance on long-run climate normals. Crop-neutral and unmasked,
  so it covers locations ASIS leaves out, but it publishes only the
  longest component of the growing period and so has no second season.
  Bounds are in **days**, the default `unit = "doy"`.

Values outside the valid range are returned as `NA`: for ASIS the flags
for no season, error, insufficient data, no cropland and water, and for
GAEZ a growing period of zero days. Use the two together when coverage
matters, taking GAEZ where ASIS is missing.

## See also

[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)

## Examples

``` r
if (FALSE) { # \dontrun{
survey |>
    read_season("asis", season = 1) |>
    weather_extremes(pre, window = window_calendar(sos, eos, unit = "dekad"))
} # }
```
