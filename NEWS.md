# c4e (development version)

c4e is the successor of `climatic4economist`, started from its v2 redesign
with the full history. `climatic4economist` 0.1 stays available unchanged
for existing scripts. The design is in `dev/PLAN_v2.md` and progress is
tracked in `dev/LOG_v2.md`.

## Done so far

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
  (`window_lag()`, `window_season()`, `window_fixed()`, `window_since()`),
  `summarise_by_interview()`, `summarise_by_period()`, `aggregate_to_adm()`.
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

## Planned

* Package hygiene, the quick start and canonical vignettes, the country case
  studies on the new names, and the first release.

# climatic4economist 0.1.0

* First version, under the old name.
