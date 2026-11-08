# Changelog

## c4e (development version)

c4e is the successor of `climatic4economist`, started from its v2
redesign with the full history. `climatic4economist` 0.1 stays available
unchanged for existing scripts. The design is in `dev/PLAN_v2.md` and
progress is tracked in `dev/LOG_v2.md`.

### Done so far

- [`read_season_by_poly()`](https://jmr-fao.github.io/c4e/reference/read_season_by_poly.md)’s
  `min_share` now gates whichever land cover supplies a division’s
  bounds, not only the first one tried. Gating only the primary cover
  let the fallback describe a division from a single cell, which
  mattered because ASIS’s second season is rare outside bimodal regimes:
  on a 20-country sample it returned a plausible second season for three
  quarters of Georgia’s divisions, every one of them from pasture at a
  median support of 0.1% of cells. With the gate, the second season
  survives where bimodality is real (Uganda 82%, Guatemala 95%, Benin
  84%) and disappears where it is not (Sahel 0-2%, Malawi 0%), and 96%
  of surviving rows come from cropland rather than pasture.

- [`read_season_by_poly()`](https://jmr-fao.github.io/c4e/reference/read_season_by_poly.md)
  summarises a crop calendar over the cells of each administrative
  division, so a division-level analysis can use a growing season as its
  window. It reports the modal and the mean start, middle and end, and
  resolves the land-cover mask: cropland governs a division where it
  covers at least `min_share` of its cells, pasture takes over where it
  does not, and `season_source` with `cropland_share` and
  `pasture_share` record what happened. Without the fallback, divisions
  in pastoral areas get no window at all and leave the analysis.

- [`read_season()`](https://jmr-fao.github.io/c4e/reference/read_season.md)
  has tests, on a miniature ASIS tree built at test time by
  `make_asis_tree()`, covering the dekad bounds, the second season
  crossing the year, and every flag value becoming `NA`.

- Labels say what a column is after
  [`aggregate_to_adm()`](https://jmr-fao.github.io/c4e/reference/aggregate_to_adm.md):
  a coverage-weighted mean over a division turns a flag from a count of
  days into the share of the division’s area beyond the threshold, and
  an excess into an area-weighted mean. The label said “days” for a
  number between 0 and 1. The kind is left alone, because the summaries
  choose their statistics by kind.

- [`bound_threshold()`](https://jmr-fao.github.io/c4e/reference/bound_threshold.md)
  holds a threshold lookup table at an absolute guardrail, so a relative
  and an absolute threshold become one threshold rather than two flags
  to combine by hand. It works on any threshold table, a percentile one
  or a user’s own zone or crop limits, which is the model thresholds
  already follow. The bound is recorded on the threshold and appears in
  the label, and a bound paired with the tail it would loosen is warned
  about.
  [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
  gains `min_threshold` and `max_threshold` as a convenience for the
  common case, which hand the finished lookup to it.

- `c4e_tbl` tables carry their context (key, variable, unit, time step,
  dates, CRS, indicator registry, history);
  [`c4e_meta()`](https://jmr-fao.github.io/c4e/reference/c4e_tbl.md),
  [`update_meta()`](https://jmr-fao.github.io/c4e/reference/c4e_tbl.md),
  [`bind_indicators()`](https://jmr-fao.github.io/c4e/reference/bind_indicators.md),
  [`c4e_history()`](https://jmr-fao.github.io/c4e/reference/c4e_history.md).

- Defaults are read from upstream and announced; large steps split by
  unit or by layer when they exceed the memory budget
  (`options(c4e.mem_limit = )`), with progress messages
  (`options(c4e.verbose = )`).

- Units:
  [`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)
  for rasters and tables, including rates per day, month or year;
  [`register_unit()`](https://jmr-fao.github.io/c4e/reference/register_unit.md),
  [`list_units()`](https://jmr-fao.github.io/c4e/reference/list_units.md).

- Rasters:
  [`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
  [`raster_meta()`](https://jmr-fao.github.io/c4e/reference/raster_meta.md),
  [`aggregate_time()`](https://jmr-fao.github.io/c4e/reference/aggregate_time.md),
  [`register_source()`](https://jmr-fao.github.io/c4e/reference/register_source.md),
  [`list_sources()`](https://jmr-fao.github.io/c4e/reference/list_sources.md);
  [`select_by_dates()`](https://jmr-fao.github.io/c4e/reference/select_by_dates.md)
  and
  [`select_by_season()`](https://jmr-fao.github.io/c4e/reference/select_by_season.md)
  work on rasters;
  [`read_boundaries()`](https://jmr-fao.github.io/c4e/reference/read_boundaries.md).

- Extraction returns `c4e_tbl` with the raster’s context, checks CRS,
  reports locations without data, buffers points and extracts in blocks
  of layers.

- Daily indicators on a matrix kernel, equal to the v1 results and up to
  900 times faster:
  [`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md),
  [`calc_condition()`](https://jmr-fao.github.io/c4e/reference/calc_condition.md),
  [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
  [`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md),
  [`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md),
  [`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md),
  [`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md),
  [`calc_heatwave()`](https://jmr-fao.github.io/c4e/reference/calc_heatwave.md).

- Standardised indices and parameters:
  [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md)
  (SPI and SPEI),
  [`calc_std_threshold()`](https://jmr-fao.github.io/c4e/reference/calc_std_threshold.md),
  and
  [`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md)
  with periods and coverage.

- Survey side: stable coordinate IDs in
  [`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md),
  window objects
  ([`window_lag()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_season()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_fixed()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md),
  [`window_calendar()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)
  with
  [`read_season()`](https://jmr-fao.github.io/c4e/reference/read_season.md)),
  [`window_lags()`](https://jmr-fao.github.io/c4e/reference/window_lags.md)
  to reach back whichever kind a window is,
  [`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md),
  [`summarise_by_period()`](https://jmr-fao.github.io/c4e/reference/summarise_by_period.md),
  [`aggregate_to_adm()`](https://jmr-fao.github.io/c4e/reference/aggregate_to_adm.md).

- Window anomalies:
  [`calc_anomaly()`](https://jmr-fao.github.io/c4e/reference/calc_anomaly.md)
  ranks the window before an interview against the same window in
  earlier years at the same location, as a percentile of the baseline or
  a z-score. The percentile assumes no distribution, which matters for
  right-skewed season totals;
  [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md)
  is the fitted-distribution form of the same idea.

- [`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)
  returns the bounds of each window, `w_start` and `w_end`, so a caller
  does not have to work out which dates a lag stands for. **This adds
  two columns to its output.**

- `summarise_by_interview(stats = list(value = ...))` summarises the
  series itself, not only the registered indicators: the window’s total,
  mean, spread and coefficient of variation as `value_sum` and the rest.

- [`snap_to_valid_cell()`](https://jmr-fao.github.io/c4e/reference/snap_to_valid_cell.md)
  moves points that fall in an empty cell to the nearest cell that has a
  value, for land-only grids whose coastline leaves a household on land
  without a cell.
  [`fill_missing_rast()`](https://jmr-fao.github.io/c4e/reference/fill_missing_rast.md)
  does the same job on the raster; this one is for when the points are
  what matters and the raster is a long daily stack.

- Export and inspection:
  [`write_stata()`](https://jmr-fao.github.io/c4e/reference/write_stata.md)
  with variable labels and a codebook,
  [`c4e_labels()`](https://jmr-fao.github.io/c4e/reference/c4e_labels.md),
  [`validate_c4e()`](https://jmr-fao.github.io/c4e/reference/validate_c4e.md),
  [`summary()`](https://rdrr.io/r/base/summary.html).

- Wrappers that run the whole chain in one call:
  [`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md),
  [`climate_indices()`](https://jmr-fao.github.io/c4e/reference/climate_indices.md),
  [`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md)
  and
  [`time_varying_controls()`](https://jmr-fao.github.io/c4e/reference/time_varying_controls.md),
  with presets
  ([`list_presets()`](https://jmr-fao.github.io/c4e/reference/list_presets.md)),
  a specification block, step progress, `dry_run`, `keep_steps`, and
  lists of surveys; options in
  [`extremes_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md),
  [`indices_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md)
  and
  [`controls_control()`](https://jmr-fao.github.io/c4e/reference/extremes_control.md).

- Every cell of a raster:
  [`grid_indicators()`](https://jmr-fao.github.io/c4e/reference/grid_indicators.md)
  (the extremes of
  [`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md),
  per year or month) and
  [`grid_controls()`](https://jmr-fao.github.io/c4e/reference/grid_controls.md)
  (population density within radii, climate normals, other layers)
  return rasters;
  [`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md),
  [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md),
  [`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md)
  and
  [`calc_std_index()`](https://jmr-fao.github.io/c4e/reference/calc_std_index.md)
  also take a `SpatRaster`. Rasters are processed in blocks of rows and
  can be written to GeoTIFF;
  [`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
  and
  [`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md)
  restore the indicator registry from the file’s tags.

- The v1 functions that the new ones replace are removed, with no
  deprecation wrappers: `climatic4economist` 0.1 keeps them for existing
  scripts. Removed: `find_extr_abs_day()`, `find_extr_rel_day()`,
  `find_extr_spell_rel()`, `find_spell()`, `find_wmo_heatwave()`,
  `calc_pct_day()`, `calc_pct_spell()`, `compute_spell()`,
  `compute_spi()`, `compute_spei()`, `compute_water_balance()`,
  `extr_std_index()`, `extr_day_index()`, `extr_spell_index()`,
  `extr_day_by_interview()`, `extr_spell_by_interview()`,
  `agg_to_adm_div()`, `aggregate_frequency()`, `ave_dist_2shp()`,
  `ave_point_density_2shp()`, `above_threshold()`, `below_threshold()`,
  `is_above()`, `is_below()`, `substitute_l()`, `substitute_u()`,
  `quantile_df()`, `quantile_na_check()`, `character_to_clock()`,
  `second_to_date()`, `is_date()`, `sort_date_columns()`. No longer
  exported (used inside the package): `filter_by_interview()`,
  `find_merge_var()`, `read_GAUL()`, `read_geoBoundaries()`,
  `sum_na_check()`, `mean_na_check()`, `max_na_check()`, `to_date()`.
  `data.table` is no longer imported.

- Lighter installation: `sf`, `exactextractr` and `furrr` move to
  Suggests and are asked for only by coverage-weighted extraction
  ([`extract_cell_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_cell_by_poly.md),
  [`extract_weighted_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_weighted_by_poly.md),
  `extract_by_poly(weights = "coverage")`) and by `.parallel = TRUE`;
  `stringi`, `tidyterra` and `raster` are no longer used.

- Every example runs on the bundled data; a pkgdown site with the
  reference grouped by task; GPL-2 licence text in `LICENSE.md`.

- Documentation: a *Get started* vignette with the six one-call
  wrappers, and six articles on the website (household extremes step by
  step, relative extremes, administrative divisions, drought indices,
  climatic parameters and spatial controls, grid indicators and maps),
  all run on the bundled data at every build.

- [`displace_coord()`](https://jmr-fao.github.io/c4e/reference/displace_coord.md)
  displaces survey coordinates before they are shared, following the DHS
  rule (urban up to 2 km, rural up to 5 km, 1% of rural up to 10 km).
  Options keep each location inside its administrative division
  (`boundaries`), out of water bodies (`water`), and set each radius so
  that at least `min_people` live within it (`population`, e.g.
  WorldPop), with the DHS limits as a floor by default. Households at a
  location move together, coordinate identifiers are rebuilt, and the
  displacement is recorded in the context, the labels and the Stata
  codebook (the seed is not).

- Compared with climatic4economist on a real survey (`dev/compare/`):

  - [`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)
    on a wide table converts every date column at once (from 25-60 s to
    under 1 s for 300 locations and 29 years of days), and the indicator
    steps match dates as numbers (thresholds and spells 3 to 5 times
    faster than before). A table already in unit-then-date order with
    every date, as each step writes it, is read without matching its
    rows, which takes another third off thresholds and spells.
  - [`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
    gives a unit and month whose values all fall beyond `exclude_below`
    (a month with no wet day) the cut-off itself, as climatic4economist
    did, so a rare wet day in that month still counts; a unit and month
    with no data stays `NA`.
  - [`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)
    and
    [`summarise_by_period()`](https://jmr-fao.github.io/c4e/reference/summarise_by_period.md)
    warn how many windows are `NA` because less than `min_coverage` of
    their days have data, and how many have no data at all.

- [`align_count_rast()`](https://jmr-fao.github.io/c4e/reference/align_count_rast.md)
  shares counts between grids that do not nest by the area of overlap,
  computed in c4e: `terra::resample(method = "sum")` gave different
  totals with different GDAL versions (16 people on Windows, 15.5 on
  Ubuntu 26.04 for the same grids).

### Planned

- The first release, on GitHub for testing, then r-universe. Case
  studies move to a separate tutorial website.
