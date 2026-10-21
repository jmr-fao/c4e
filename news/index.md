# Changelog

## c4e (development version)

c4e is the successor of `climatic4economist`, started from its v2
redesign with the full history. `climatic4economist` 0.1 stays available
unchanged for existing scripts. The design is in `dev/PLAN_v2.md` and
progress is tracked in `dev/LOG_v2.md`.

### Done so far

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
  [`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)),
  [`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md),
  [`summarise_by_period()`](https://jmr-fao.github.io/c4e/reference/summarise_by_period.md),
  [`aggregate_to_adm()`](https://jmr-fao.github.io/c4e/reference/aggregate_to_adm.md).

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

### Planned

- Three case-study articles and `displace_coord()` for privacy, then the
  first release.
