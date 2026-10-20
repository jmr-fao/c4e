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

## Planned

* Two grid wrappers and grid methods of the indicators.
* The v1 functions that the new ones replace are removed before the first
  release; there are no deprecation wrappers, since `climatic4economist`
  keeps them.

# climatic4economist 0.1.0

* First version, under the old name.
