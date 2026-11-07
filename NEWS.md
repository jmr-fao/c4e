# c4e (development version)

c4e is the successor of `climatic4economist`, started from its v2 redesign
with the full history. `climatic4economist` 0.1 stays available unchanged
for existing scripts. The design is in `dev/PLAN_v2.md` and progress is
tracked in `dev/LOG_v2.md`.

## Done so far

* Labels say what a column is after `aggregate_to_adm()`: a coverage-weighted
  mean over a division turns a flag from a count of days into the share of the
  division's area beyond the threshold, and an excess into an area-weighted
  mean. The label said "days" for a number between 0 and 1. The kind is left
  alone, because the summaries choose their statistics by kind.

* `c4e_tbl` tables carry their context (key, variable, unit, time step,
  dates, CRS, indicator registry, history); `c4e_meta()`, `update_meta()`,
  `bind_indicators()`, `c4e_history()`.
* Defaults are read from upstream and announced; large steps split by unit
  or by layer when they exceed the memory budget
  (`options(c4e.mem_limit = )`), with progress messages
  (`options(c4e.verbose = )`).
* Units: `convert_unit()` for rasters and tables, including rates per day,
  month or year; `register_unit()`, `list_units()`.
* Rasters: `read_climate()`, `raster_meta()`, `aggregate_time()`,
  `register_source()`, `list_sources()`; `select_by_dates()` and
  `select_by_season()` work on rasters; `read_boundaries()`.
* Extraction returns `c4e_tbl` with the raster's context, checks CRS,
  reports locations without data, buffers points and extracts in blocks of
  layers.
* Daily indicators on a matrix kernel, equal to the v1 results and up to
  900 times faster: `calc_threshold_day()`, `calc_condition()`,
  `calc_percentile()`, `calc_percentile_day()`, `calc_spell()`,
  `calc_spell_percentile()`, `calc_spell_excess()`, `calc_heatwave()`.
* Standardised indices and parameters: `calc_std_index()` (SPI and SPEI),
  `calc_std_threshold()`, and `calc_par()` with periods and coverage.
* Survey side: stable coordinate IDs in `prepare_coord()`, window objects
  (`window_lag()`, `window_season()`, `window_fixed()`, `window_since()`,
  `window_calendar()` with `read_season()`), `window_lags()` to reach back
  whichever kind a window is, `summarise_by_interview()`,
  `summarise_by_period()`, `aggregate_to_adm()`.
* Window anomalies: `calc_anomaly()` ranks the window before an interview
  against the same window in earlier years at the same location, as a
  percentile of the baseline or a z-score. The percentile assumes no
  distribution, which matters for right-skewed season totals;
  `calc_std_index()` is the fitted-distribution form of the same idea.
* `summarise_by_interview()` returns the bounds of each window, `w_start`
  and `w_end`, so a caller does not have to work out which dates a lag
  stands for. **This adds two columns to its output.**
* `summarise_by_interview(stats = list(value = ...))` summarises the series
  itself, not only the registered indicators: the window's total, mean,
  spread and coefficient of variation as `value_sum` and the rest.
* `snap_to_valid_cell()` moves points that fall in an empty cell to the
  nearest cell that has a value, for land-only grids whose coastline leaves
  a household on land without a cell. `fill_missing_rast()` does the same
  job on the raster; this one is for when the points are what matters and
  the raster is a long daily stack.
* Export and inspection: `write_stata()` with variable labels and a
  codebook, `c4e_labels()`, `validate_c4e()`, `summary()`.
* Wrappers that run the whole chain in one call: `weather_extremes()`,
  `climate_indices()`, `static_controls()` and `time_varying_controls()`,
  with presets (`list_presets()`), a specification block, step progress,
  `dry_run`, `keep_steps`, and lists of surveys; options in
  `extremes_control()`, `indices_control()` and `controls_control()`.

* Every cell of a raster: `grid_indicators()` (the extremes of
  `weather_extremes()`, per year or month) and `grid_controls()` (population
  density within radii, climate normals, other layers) return rasters;
  `calc_threshold_day()`, `calc_percentile()`, `calc_par()` and
  `calc_std_index()` also take a `SpatRaster`. Rasters are processed in
  blocks of rows and can be written to GeoTIFF; `extract_by_coord()` and
  `extract_by_poly()` restore the indicator registry from the file's tags.

* The v1 functions that the new ones replace are removed, with no
  deprecation wrappers: `climatic4economist` 0.1 keeps them for existing
  scripts. Removed: `find_extr_abs_day()`, `find_extr_rel_day()`,
  `find_extr_spell_rel()`, `find_spell()`, `find_wmo_heatwave()`,
  `calc_pct_day()`, `calc_pct_spell()`, `compute_spell()`, `compute_spi()`,
  `compute_spei()`, `compute_water_balance()`, `extr_std_index()`,
  `extr_day_index()`, `extr_spell_index()`, `extr_day_by_interview()`,
  `extr_spell_by_interview()`, `agg_to_adm_div()`, `aggregate_frequency()`,
  `ave_dist_2shp()`, `ave_point_density_2shp()`, `above_threshold()`,
  `below_threshold()`, `is_above()`, `is_below()`, `substitute_l()`,
  `substitute_u()`, `quantile_df()`, `quantile_na_check()`,
  `character_to_clock()`, `second_to_date()`, `is_date()`,
  `sort_date_columns()`. No longer exported (used inside the package):
  `filter_by_interview()`, `find_merge_var()`, `read_GAUL()`,
  `read_geoBoundaries()`, `sum_na_check()`, `mean_na_check()`,
  `max_na_check()`, `to_date()`. `data.table` is no longer imported.

* Lighter installation: `sf`, `exactextractr` and `furrr` move to
  Suggests and are asked for only by coverage-weighted extraction
  (`extract_cell_by_poly()`, `extract_weighted_by_poly()`,
  `extract_by_poly(weights = "coverage")`) and by `.parallel = TRUE`;
  `stringi`, `tidyterra` and `raster` are no longer used.
* Every example runs on the bundled data; a pkgdown site with the reference
  grouped by task; GPL-2 licence text in `LICENSE.md`.

* Documentation: a *Get started* vignette with the six one-call wrappers, and
  six articles on the website (household extremes step by step, relative
  extremes, administrative divisions, drought indices, climatic parameters
  and spatial controls, grid indicators and maps), all run on the bundled
  data at every build.

* `displace_coord()` displaces survey coordinates before they are shared,
  following the DHS rule (urban up to 2 km, rural up to 5 km, 1% of rural
  up to 10 km). Options keep each location inside its administrative
  division (`boundaries`), out of water bodies (`water`), and set each
  radius so that at least `min_people` live within it (`population`, e.g.
  WorldPop), with the DHS limits as a floor by default.
  Households at a location move together, coordinate identifiers are
  rebuilt, and the displacement is recorded in the context, the labels and
  the Stata codebook (the seed is not).

* Compared with climatic4economist on a real survey (`dev/compare/`):
  * `convert_unit()` on a wide table converts every date column at once
    (from 25-60 s to under 1 s for 300 locations and 29 years of days), and
    the indicator steps match dates as numbers (thresholds and spells 3 to
    5 times faster than before). A table already in unit-then-date order
    with every date, as each step writes it, is read without matching its
    rows, which takes another third off thresholds and spells.
  * `calc_percentile()` gives a unit and month whose values all fall beyond
    `exclude_below` (a month with no wet day) the cut-off itself, as
    climatic4economist did, so a rare wet day in that month still counts;
    a unit and month with no data stays `NA`.
  * `summarise_by_interview()` and `summarise_by_period()` warn how many
    windows are `NA` because less than `min_coverage` of their days have
    data, and how many have no data at all.

* `align_count_rast()` shares counts between grids that do not nest by the
  area of overlap, computed in c4e: `terra::resample(method = "sum")` gave
  different totals with different GDAL versions (16 people on Windows, 15.5
  on Ubuntu 26.04 for the same grids).

## Planned

* The first release, on GitHub for testing, then r-universe. Case studies move to a
  separate tutorial website.

# climatic4economist 0.1.0

* First version, under the old name.
