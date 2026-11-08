# Growing-season bounds for each administrative division

Summarises a published crop calendar over the cells of each division, so
a division-level analysis can use a growing season as its window. The
points equivalent is
[`read_season()`](https://jmr-fao.github.io/c4e/reference/read_season.md).

## Usage

``` r
read_season_by_poly(
  boundaries,
  source = "asis",
  season = 1,
  land_cover = c("cropland", "pasture"),
  stat = c("mode", "mean"),
  min_share = 0.1,
  id = NULL,
  path = NULL
)
```

## Arguments

- boundaries:

  A `SpatVector` of divisions, from
  [`read_boundaries()`](https://jmr-fao.github.io/c4e/reference/read_boundaries.md).

- source:

  Only `"asis"`. GAEZ publishes no land-cover mask and no second season,
  so it has nothing to summarise per division that
  [`read_season()`](https://jmr-fao.github.io/c4e/reference/read_season.md)
  does not already give per point.

- season:

  `1` or `2`.

- land_cover:

  `"cropland"`, `"pasture"`, or both for cropland with pasture where
  cropland is absent.

- stat:

  `"mode"`, `"mean"` or both.

- min_share:

  The share of a division's cells that must carry a season before that
  season describes the division. It gates whichever land cover supplies
  the bounds, not only the first: a division where cropland falls short
  falls back to pasture, and if pasture falls short too the division
  gets no season rather than one resting on a handful of cells.

- id:

  Name of the division column in `boundaries`; `ID_adm_div` by default.

- path:

  The dataset folder, if it is not in the spatial repository found by
  [`find_nested_folder()`](https://jmr-fao.github.io/c4e/reference/find_nested_folder.md).

## Value

A tibble with one row per division: the division id, the requested
bounds, `season_share` (the share of the division's cells carrying the
season it was given), `cropland_share`, `pasture_share` and
`season_source`. The unit is in the `"season_unit"` attribute.

## Details

Two choices arise that never arise for a point, and both are recorded in
the result rather than hidden:

**Which statistic.** A division spans many cells and rarely one
calendar. `stat` takes `"mode"`, `"mean"` or both, giving `sos_mode`,
`sos_mean` and so on. The mode is the usual choice: it answers "when
does this division mostly sow", and a handful of cells on another system
does not move it. The mean is reported alongside because a wide gap
between the two is itself the finding that a division has no single
season.

**Which land cover.** ASIS masks its phenology to cropland
(`"cropland"`) or pasture (`"pasture"`). Give both, the default, and
cropland governs wherever it covers at least `min_share` of a division's
cells, with pasture taking over where it does not. That matters in
pastoral areas, where the cropland mask is empty over much of the
territory: without the fallback those divisions get no window and drop
out of the analysis, which is selection on exactly the thing being
studied. `season_source` records which cover each division ended up on,
and `cropland_share` and `pasture_share` are both reported, so the
choice can be audited or overridden.

`min_share` gates the cover that is actually used, which matters more
than it sounds. A modal dekad over whatever cells survive the flag mask
will describe a division from a single cell if that is all there is, and
the value will look perfectly ordinary — a confident wrong season is
harder to notice than a missing one. ASIS's second season is rare
outside bimodal regimes (0.2% of Niger's cells carry one, against 29%
for the first), so without the gate `season = 2` returns a
plausible-looking window for nearly every division in a unimodal
country.

ASIS defines the end of season with a different NDVI threshold on
cropland than elsewhere, so `eos` from the two covers is not strictly
the same quantity; `sos` is less affected. Read `season_source` before
comparing season *lengths* across divisions.

Bounds are dekads, signed and linear from 1 January: a second season
reaching into the next year is 40, not 4, and one starting in the
previous year is negative. Pass `unit = "dekad"` to
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md).

## See also

[`read_season()`](https://jmr-fao.github.io/c4e/reference/read_season.md),
[`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)

## Examples

``` r
if (FALSE) { # \dontrun{
divisions <- read_boundaries(path, iso = "NER", level = 2)
seasons <- read_season_by_poly(divisions, season = 1)
table(seasons$season_source)
} # }
```
