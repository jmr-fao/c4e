# c4e — progress log (started as climatic4economist v2)

Handoff document for v2 development. Read this first in every session, on any
laptop; the design is in `dev/PLAN_v2.md` (section numbers below refer to it).

## Status (update at the end of every session)

| # | Chunk | State | PR | Started | Done | Notes |
|---|---|---|---|---|---|---|
| 0 | Scaffold | ✔ done | | 2026-10-16 | 2026-10-19 | pushed; CI fixed on 2026-10-19 (examples, `withr`) |
| 1 | `c4e_tbl` class | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| 2 | Defaults, messages, history, chunking | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| 3 | Units | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| 4 | Raster readers | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| 5 | Extraction | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| 6 | Matrix kernel | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| 7 | Daily indicators | ✔ done | | 2026-10-19 | 2026-10-19 | in `c4e` `main` (seeded from `v2-chunk-7`) |
| R | Rename to `c4e` (new repository) | ✔ done | | 2026-10-20 | 2026-10-20 | `jmr-fao/c4e` created (public) and `main` pushed on 2026-10-20; Actions enabled |
| 8 | Standardised indices and parameters | ✔ done | #1 | 2026-10-20 | 2026-10-20 | merged into `main` |
| 9 | Survey side | ✔ done | #2 | 2026-10-20 | 2026-10-20 | merged into `main` with the stack |
| 10 | Export and inspection | ✔ done | #3 | 2026-10-20 | 2026-10-20 | merged into `main` with the stack |
| 11 | Wrappers and presets | ✔ done | #4 | 2026-10-20 | 2026-10-20 | merged into `main` with the stack; also the cv safeguard, README and topics |
| 12 | Grid methods and wrappers | ✔ done | | 2026-10-20 | 2026-10-20 | merged into `main` by a direct push (no pull request); CI green on `main` |
| 13 | Removal of the v1 functions | ✔ done | #5 | 2026-10-21 | 2026-10-21 | merged into `main` |
| 14 | Package hygiene | ✔ done | #6 | 2026-10-21 | 2026-10-21 | merged into `main`; README and title in #7, #8; site live |
| 15 | Quick start and canonical vignettes | ✔ done | #9 | 2026-10-21 | 2026-10-21 | merged into `main`; site live with Get started and six articles |
| 16 | Privacy and case studies | 🔄 in progress | | 2026-10-21 | | `displace_coord()` complete on branch `chunk-16-displace`; the case studies move to a separate tutorial site |
| 17 | Release c4e 0.1.0 (GitHub first, r-universe after testing) | ☐ | | | | |
| 18 | Paper (JOSS) | 🔄 in progress | | 2026-10-21 | | draft in `paper/` on branch `joss-paper` |

States: ☐ not started · 🔄 in progress · 👀 in review (PR open) · ✔ done · ⛔ blocked

**Current chunk:** 16. `displace_coord()` is complete on branch
`chunk-16-displace` (cut from `main`); it needs a push and a pull request.

**Next steps (in order):**
1. Merge pull request #10 (`chunk-16-displace`) into `main` when
   both checks are green.
2. Chunk 17, the release (plan §8 row 17): a GitHub release only, for
   colleagues to test; r-universe after their feedback, CRAN later. Jan: the author's full name for `DESCRIPTION`.
3. The JOSS paper (plan §8 row 18): draft on branch `joss-paper`
   (stacked on `chunk-16-displace`). Jan: ORCID, affiliation, the projects
   that used c4e or climatic4economist (research impact), acknowledgements;
   then the release DOI (Zenodo) and submission.
4. Separately: the tutorial website `jmr-fao/c4e-tutorials` (Quarto, GitHub
   Pages) with the three case studies (one country with household
   coordinates and division controls; several countries with
   `purrr::map()`; a narrow project with distances and the cost of
   displacement) and the scripts of `case_studies/`, which then leave this
   repository.
5. Left from chunk 11 (see decisions): `c4e_history()` prints a readable
   template of a wrapper's chain, not code that re-evaluates: the survey and
   raster inputs are not in it and `window` prints as a list. Make it
   evaluable (record windows as `window_lag(...)` calls, data arguments as
   placeholders) alongside chunk 12 or in chunk 14. Also not built:
   `climate_indices(wide = TRUE)` and a `baseline` for SPI.
6. Step functions follow this pattern: `meta <- c4e_meta(x) %||%
   empty_meta()`, `started <- Sys.time()`, resolve each argument with
   `c4e_default()`, announce with `c4e_progress_step()` only when a `label`
   is given, wrap heavy work in `with_chunks()` with a `mem_estimate`, and
   return `new_c4e_tbl(out, c4e_record(meta, fn, args, started))`.

**Blocked / needs Jan:**
- This laptop runs R 4.5.0 with packages built for 4.5.3; namespace loads in
  fresh workers warn "built under R version 4.5.3". Not a code problem.

## Decisions and deviations from the plan

| Date | Section | Decision | Why |
|---|---|---|---|
| 2026-10-16 | §8 | Chunk 0 commits locally; pushing is left to Jan | pushing a branch is outward-facing |
| 2026-10-16 | §2, §13 | `read_climate()` must not rely on `terra::varnames()` for the variable: on read, terra replaces it with the file name (`tmax_daily`). Store the variable in `terra::metags()` and fall back to an explicit argument. `time()` and `units()` do round-trip through GeoTIFF. | found while building fixtures |
| 2026-10-16 | §8 chunk 0 | The fixture generator lives in `dev/make_fixtures.R` (build-ignored), not in a `data-raw/` folder | keeps all v2 development material in one place |
| 2026-10-16 | §8 chunk 0 | `.gitignore` keeps ignoring every `.tif`/`.gpkg` but re-includes `inst/extdata/*.tif` and `*.gpkg` | protect real data while tracking the synthetic fixtures |
| 2026-10-19 | §8 chunks 0, 14 | R-CMD-check is a real gate from now on, not "allowed to fail until chunk 14". Every chunk must leave 0 ERRORs and 0 WARNINGs; NOTEs stay for chunk 14. | Jan asked for the check to pass for real |
| 2026-10-19 | §3 | `merge_by_common()` list form fixed now (reduce over the list) instead of in chunk 9 | its example exposed the bug |
| 2026-10-19 | §1, §11.5 | Indicator `kind` for threshold flags is `"flag"`, not `"day"`; plan §1 edited | §11.5 already planned the rename so hourly and monthly flags fit; doing it now avoids a later migration |
| 2026-10-19 | §1 | Grouped operations need explicit `group_by()`, `ungroup()`, `dplyr_col_modify()` and `dplyr_row_slice()` methods, and `names<-` must rebuild through the constructor; plan §1 table rewritten | probed on dplyr 1.2.1: without them `group_by()` drops the subclass and grouped `mutate`/`filter`/`select` lose the metadata |
| 2026-10-19 | §1, §12, §14 | `dplyr::bind_rows()` keeps only the first table's metadata; `vctrs::vec_rbind()` merges. Package code that stacks results uses `vec_rbind()`; plan §12 edited | dplyr strips attributes before `dplyr_reconstruct()`, so no method can merge there |
| 2026-10-19 | §1 | Conflicting `window`/`spatial_agg`/`survey` fields are cleared on merge, like every other single-valued field, instead of "keep the first with a warning" | one rule for all single-valued fields; the per-indicator registry keeps what matters |
| 2026-10-19 | §1 | Exported in chunk 1: `c4e_meta()`, `is_c4e_tbl()`, `update_meta()`, `bind_indicators()`. Internal: `new_c4e_tbl()`, `new_indicator()`, `add_indicator()`, `modify_meta()`, `merge_meta()`, `prune_meta()`, `rename_meta()` | keep the public surface small until the step functions exist |
| 2026-10-19 | §8 | Chunk 2 branched from `v2-chunk-1` instead of from `v2` after the merge | Jan asked to start chunk 2 before chunk 1 was pushed |
| 2026-10-19 | §1 | `c4e_default()` takes a `field` argument so the message names the metadata field; values print as typed (`c(30, 35)`, `"C"`, `as.Date(...)`); hard defaults are silent, upstream values are announced | the message must say exactly what was used and where it came from |
| 2026-10-19 | §9.6, §12 | History keeps only arguments that can be written as code; data arguments (raster, survey, tables, functions) are left out, so `c4e_history()` prints the steps with the data arguments for the user to supply. The §12 "history re-evaluates" check is restated accordingly | rasters and tables cannot be stored as code and would bloat the metadata |
| 2026-10-19 | §14 | `merge_meta()` keeps identical history entries once (`unique()`) | the pieces of one split share their earlier steps, which would otherwise repeat once per piece |
| 2026-10-19 | §14 | `with_chunks(.parallel = TRUE)` calls `furrr::future_map()` under whatever `future::plan()` the user set, without a progress bar | `future` is not imported, and a bar cannot follow workers without `progressr` |
| 2026-10-19 | §14 | `with_chunks()` accepts a named list of tables split on the same units, for `summarise_by_interview()` (survey + indicators) | chunk 9 needs both sides of the join cut on the same locations |
| 2026-10-19 | §14 | Exported in chunk 2: `c4e_history()` (with a print method). Internal: `c4e_default()`, `check_meta_agrees()`, `c4e_inform()`, `c4e_progress_step()`, `resolve_label()`, `c4e_record()`, `mem_budget()`, `parse_bytes()`, `format_bytes()`, `estimate_bytes()`, `with_chunks()`. Options `climatic4economist.verbose` and `climatic4economist.mem_limit` are documented in `?climatic4economist` | users see the history; the rest is plumbing for the step functions |
| 2026-10-19 | §8 | Chunk 3 branched from `v2-chunk-2` | Jan asked to start it before chunks 1 and 2 were pushed |
| 2026-10-19 | §2 | Rates are converted generically (quantity through the simple table, time denominator by its length) instead of listing each rate conversion; plan §2 edited | covers kg/m2/s, mm/day, m/s and project units without one row per pair |
| 2026-10-19 | §2 | Registry columns convert by role: `pct` and level `par` stats as levels, `excess`, spread `par` stats and `agg` of excess as differences (factor only), counts never; numeric thresholds as levels | a K to C conversion must leave "5 degrees above the threshold" at 5 |
| 2026-10-19 | §2 | `convert_unit()` gains `cols` (tidy-select) for tables whose series is not in date columns or `value` | lets a plain table with `tmax`, `tmin` columns convert without renaming |
| 2026-10-19 | §2, §11.7 | Exported in chunk 3: `convert_unit()` (SpatRaster, c4e_tbl, data.frame methods), `register_unit()`, `list_units()`. Internal: `canonical_unit()`, `unit_conversion()`, `rate_factor()`, `infer_time_step()`, `resolve_unit()`, `reset_units()` | `list_units()` makes the registry discoverable |
| 2026-10-19 | §2 | The degree sign in the alias table is built with `intToUtf8(176)` | R CMD check requires ASCII R code; the editing tools turned `\u00b0` escapes into the literal character |
| 2026-10-19 | §8 | Chunk 4 branched from `v2-chunk-3` | Jan asked to start it before the earlier chunks were pushed |
| 2026-10-19 | §2, §13 | Raster context is stored twice: `terra::metags()` for files and `varnames()`/`longnames()` for memory; `raster_meta()` reads either. Plan §2 edited | probed on terra 1.9.46: metags survive GeoTIFF but not `r[[i]]`, arithmetic or `rotate()`; longnames survive in-memory steps but not file reads, and arithmetic on multi-file rasters |
| 2026-10-19 | §2 | `longnames()` is set to one string, which terra applies to every data source | terra rejects one value per layer (longnames belong to sources) |
| 2026-10-19 | §2, §11.7 | `register_source(name, detect, variable, unit, kind, time)` instead of `register_source(name, time_from, unit, variable_from)`: each convention is a fixed value or a function of the raster and its files | covers ERA5 layer names, CHIRPS file-name dates and fixed GAEZ kinds with one shape |
| 2026-10-19 | §2 | `read_boundaries()` attaches no metadata to the SpatVector | terra 1.9.46 has no `metags()` for vectors; level and iso stay in the attribute columns |
| 2026-10-19 | §3, §9.8 | `select_by_dates()` and `select_by_season()` are S3 generics with an anchored date pattern; the first argument is now `x` (was `df`) | raster methods needed; the unanchored `[0-9]{4}` took columns such as `MAX_2020` for dates (bug listed in §9.8) |
| 2026-10-19 | §2 | `aggregate_time()` names layers by the full ISO start date of each period, also for months and years | one date format for every step; `lubridate`/`clock` parse it everywhere |
| 2026-10-19 | §8 chunk 0 | Fixtures now carry package metadata (`c4e_*` metags); values, dates and geometry unchanged (checked against the committed files); `adm_div.gpkg` left as committed | lets the tests read the fixtures the way users will read package-written files |
| 2026-10-19 | tests | `make_gaul_tree()` and `make_boundary_tree()` moved from their test files to `tests/testthat/helper-boundaries.R` | `read_boundaries()` tests reuse them |
| 2026-10-19 | §2 | Exported in chunk 4: `read_climate()`, `raster_meta()`, `aggregate_time()`, `register_source()`, `list_sources()`, `read_boundaries()`, and the `select_by_dates()`/`select_by_season()` methods | |
| 2026-10-19 | §8 | Chunk 5 branched from `v2-chunk-4` | Jan asked to start it before the earlier chunks were pushed |
| 2026-10-19 | §14 | Steps show a progress step only when given a `label` (or `iteration`), not by default from `meta$label` | a step on every extraction is noise in pipelines, and the printed durations make snapshots unstable; the wrappers (chunk 11) drive their own steps |
| 2026-10-19 | §3 | Extracted value columns are named after the layers (`2021-01-01`) instead of terra's sanitised `X2021_01_01` | one name throughout; `date_pattern()` and `to_date()` accept both, so v1 functions still work |
| 2026-10-19 | §2 | `read_climate()` ignores the stored context when an explicit `variable` differs from the stored one | a raster built on another's template (`terra::rast(template, vals =)`) inherits its longnames, which describe the template's variable |
| 2026-10-19 | §14 | `extract_by_coord()` and `extract_cell_by_poly()` split by layers (`extract_in_blocks()`), not by units; their `chunk` counts layers per block | the result grows with the number of layers; every block keeps the same rows, so blocks bind side by side |
| 2026-10-19 | §3, §10.4 | `raster` moved from Imports to Suggests | only the legacy `ave_point_density_2shp()` still calls `raster::`; it is removed in chunk 13 |
| 2026-10-19 | §2 | `fill_missing_rast(fun)` defaulting from the kind is not done yet | not part of chunk 5; left for chunk 14 or whichever chunk touches it first |
| 2026-10-19 | §8 | Chunk 6 branched from `v2-chunk-5` | Jan asked to start it before the earlier chunks were pushed |
| 2026-10-19 | §13 | Rasters run the kernel through `apply_kernel_raster()` (own block reading and writing), not `terra::app()`; plan §13 and row 12 edited | probed on terra 1.9.46: `app()` calls its function once per cell with a vector, never with a block matrix |
| 2026-10-19 | §10.2 | `spi_matrix()` fits each series on its own, with optional `furrr`; plan §10.2 edited | probed on SPEI 1.8.1: one call on a matrix gives the same numbers but took 9.2 s against 3.6 s for 300 series |
| 2026-10-19 | §10.1 | `row_quantiles()` reproduces R's type-7 interpolation code exactly, vectorised over rows | v1 equality must hold, not just closeness |
| 2026-10-19 | §10.7 | Benchmark at 1,000 units × 1,095 days and 10,000 units × 365 days rather than 10,000 × 1,095; results in `inst/bench/results.md`; `inst/bench` is build-ignored | v1 monthly percentiles alone took an hour at 10,000 × 365; the scripts are development tools |
| 2026-10-19 | §8 | Chunk 7 branched from `v2-chunk-6` | Jan asked to start it before the earlier chunks were pushed |
| 2026-10-19 | §3 | Indicator steps add their columns to the long table they receive; `calc_spell()` keeps the flags, unlike v1 `find_spell()` | one table accumulates indicators, so `bind_indicators()` is only needed across variables |
| 2026-10-19 | §1 | History records the arguments a step used, including values taken from upstream (e.g. `unit = "K"`) | the record must reproduce the step without the earlier context |
| 2026-10-19 | §3 | `calc_percentile(replace = NA)`: a unit and month with no value left gets `NA`; v1 returned the exclusion threshold (`replace = c(l_thresh, u_thresh)`) and errored without one | the v1 value made every wet day "extreme" in a dry month; `NA` flags nothing |
| 2026-10-19 | §3 | `calc_spell_excess()` registers its columns as `kind = "excess"` with `unit = "days"` | an excess in days must never be touched by `convert_unit()` |
| 2026-10-19 | §3 | `calc_heatwave()` requires temperatures in C or K (from upstream or `unit`) | the WMO excess is in degrees; it is the same in C and K |
| 2026-10-19 | §11.1, §11.2, §11.5 | Done in chunk 7: thresholds from a table by unit (and month), `calc_condition()`, flag prefixes by time step (`day_`, `hr_`, `mo_`, `yr_`) | they share the same code path as numeric thresholds |
| 2026-10-19 | §8 | The v1 indicator tests (`test-thresholds.R`, `test-spells.R`, `test-find-extr-rel-day.R`, `test-invariants.R`) are kept unchanged instead of migrated | the v1 functions still exist; they become wrappers, and their tests move, in chunk 13 |
| 2026-10-19 | §3 | Exported in chunk 7: `calc_threshold_day()`, `calc_condition()`, `calc_percentile()`, `calc_percentile_day()`, `calc_spell()`, `calc_spell_percentile()`, `calc_spell_excess()`, `calc_heatwave()` | |
| 2026-10-20 | all | v2 continues as the new package `c4e` in its own repository, seeded from `v2-chunk-7` with the full history; `climatic4economist` 0.1 stays unchanged | Jan's decision: shorter `c4e::` calls, matches the `c4e_*` names, and old scripts keep working without deprecation warnings |
| 2026-10-20 | §8 | In `c4e`, chunks merge into `main` by pull request; there is no separate `v2` branch | a new package has no released `main` to protect |
| 2026-10-20 | §1, §14 | Options renamed to `c4e.verbose` and `c4e.mem_limit` | follow the package name |
| 2026-10-20 | §8 chunk 13 | No deprecation wrappers. Before the replaced v1 functions are removed, their outputs on the fixtures are saved as reference files for the equality tests | the old names live on in `climatic4economist` |
| 2026-10-20 | §8 | Version restarts at `0.1.0.9000`; the first release is `c4e` 0.1.0 (or 1.0.0) | new package |
| 2026-10-20 | §14 | DESCRIPTION title and description rewritten; the "title case" and "complete sentences" R CMD check notes are gone | part of the rename |
| 2026-10-20 | repo | `CLAUDE.md` and `AGENTS.md` rewritten for `c4e` (AGENTS.md mirrors CLAUDE.md); the old vignettes still call `climatic4economist::` and are ported in chunks 15 and 16 | the instructions must name the right package and branch rules |
| 2026-10-20 | §3 | `calc_par()` is rewritten in place under the same name: `pars` → `fn` (also accepts function names or one function), `agg_period` → `period`, `prefix` defaults to the variable (announced; `FALSE` for none); v1's windows anchored on the last date and its coverage rule are kept | the name was already right; equality with v1 is checked against saved outputs |
| 2026-10-20 | §8 chunk 13 | Reference files start now: `dev/make_references.R` saves v1 outputs on the fixtures to `tests/testthat/fixtures/v1_<function>.rds` before a v1 function is replaced; first file `v1_calc_par.rds` | chunk 8 replaces `calc_par()` in place, so v1 cannot be called at test time |
| 2026-10-20 | §3 | SPEI water balance is precipitation minus the absolute evapotranspiration, matched by unit and date; v1 added PET by column position, expecting ERA5's negative sign | works with either sign convention and never mismatches columns |
| 2026-10-20 | §3 | `calc_std_index()` takes several scales at once (`spi_1`, `spi_3`, ...); `transform` records them all | one call per variable instead of one per scale |
| 2026-10-20 | §3 | Exported in chunk 8: `calc_std_index()`, `calc_std_threshold()`; `calc_par()` changed signature | |
| 2026-10-20 | §8 | Chunk 9 branched from `chunk-8-std-index` | Jan asked to start it before chunk 8 was pushed |
| 2026-10-20 | §9.1 | `prepare_coord()` IDs are built from the coordinates by default (`"30.12340_-0.54320"`, 5 decimals); `id_rule = "sequence"` gives v1's `"1"`, `"2"`, ... | the same location gets the same ID in every wave, subset and run |
| 2026-10-20 | §3 | `prepare_coord()` keeps `lat_var`/`lon_var`, and `summarise_by_interview()` keeps v1's `by`/`id`/`interview`, instead of the `lon`/`lat` names in plan §3 | every existing script and test uses these names |
| 2026-10-20 | §9.3 | Windows with less than `min_coverage` (default 0.8) of their days present, and windows with no data, give `NA` instead of v1's 0 or a dropped row | a count from half a window looks complete but is not |
| 2026-10-20 | §11.3 | Season windows take the last season whose end is before the interview day; fixed windows are inclusive of `from` and `to`; since-windows run from the event to the day before the interview | |
| 2026-10-20 | §3 | `aggregate_to_adm()` groups by division and any of `lag`, date, `month`, `period`, so it works on daily cell tables (giving area shares per day) as well as on window summaries | v1 grouped by division and lag only |
| 2026-10-20 | §3 | `merge_with_survey()` returns a `c4e_tbl` when `new_value` has context, records the survey columns, and warns when a long table would explode beyond the memory budget | |
| 2026-10-20 | tests | The `calc_par()` references, saved with v1's sequential IDs, are matched by cell coordinates | the coordinate IDs differ from the saved ones |
| 2026-10-20 | §3 | Exported in chunk 9: `summarise_by_interview()`, `summarise_by_period()`, `window_lag()`, `window_season()`, `window_fixed()`, `window_since()`, `aggregate_to_adm()`; `prepare_coord()`, `georef_coord()`, `merge_with_survey()` extended | |
| 2026-10-20 | §8 | Chunk 10 branched from `chunk-9-survey` | Jan asked to start it before chunk 9 was pushed |
| 2026-10-20 | §6 | `write_stata()` names columns with its own rule (`-` before a digit → `m`, `.` between digits → `p`, other invalid characters → `_`; date columns as in v1); `to_stata_format()` is unchanged | `to_stata_format()` turns `-1.5` into `_15`, which collides with a threshold of 15 |
| 2026-10-20 | §6 | Labels of window summaries use a short window phrase ("per 1-year window"); the `lag` column carries the full window description | full descriptions pushed labels past Stata's 80 characters |
| 2026-10-20 | §6 | `c4e_labels()` is exported; `indicator_label()` stays internal | users and the codebook need the labels without writing a file |
| 2026-10-20 | §9.7 | `validate_c4e()` checks duplicate rows, empty indicators, units without data and date gaps; `summary.c4e_tbl()` adds the context, counts, and per-indicator missing share and mean | |
| 2026-10-20 | §3 | Window-summary registry entries now record their source's kind (`of`), step and definition | labels must know whether a sum is of days or of an excess |
| 2026-10-20 | §6 | Exported in chunk 10: `write_stata()`, `c4e_labels()`, `validate_c4e()`, `summary()` method for `c4e_tbl` | |
| 2026-10-20 | §12 | The control wrappers live in `R/controls.R`; `R/wrappers.R` holds the shared machinery, `weather_extremes()` and `climate_indices()` | two files of readable length |
| 2026-10-20 | §12 | Wrappers convert units after extraction, on the table (`convert_unit()` appears in the history): to the preset's unit, else Kelvin data with thresholds below 100 to C, precipitation in m or kg/m2/s to mm | one place for conversions, visible in the history |
| 2026-10-20 | §12 | Spell percentiles and their excess only with `extremes_control(spell_excess = TRUE)`, not by default with `p` | they double the columns and few analyses use them |
| 2026-10-20 | §12 | With `boundaries`, divisions are attached to households by point in polygon and indicators summarised with `by = "ID_adm_div"`; distances in `static_controls()` stay at the household's own location | |
| 2026-10-20 | §12 | Control columns are registered as `kind = "par"` with `stat` (`value`, `mean`, `mode`, `sum`, `density`, `distance`, `log1p`), `buffer` and `period` (`static` or the `match` rule); normals carry `years` | no new indicator kind; labels follow from these fields |
| 2026-10-20 | §12 | A list of surveys is bound with `vec_rbind()` after adding `survey` to each table, not with `.names_to` | `.names_to` binds through a plain tibble prototype and drops the registry |
| 2026-10-20 | §12 | Not built in chunk 11: `climate_indices(wide = TRUE)`, `baseline` for SPI, `select_by_dates()` of the window span before extraction, an evaluable `c4e_history()` | kept the chunk to the four wrappers; listed in Next steps |
| 2026-10-20 | §12 | Exported in chunk 11: `weather_extremes()`, `climate_indices()`, `static_controls()`, `time_varying_controls()`, `list_presets()`, `extremes_control()`, `indices_control()`, `controls_control()` | |
| 2026-10-20 | §3, §11 | `calc_par()` computes coefficients of variation (statistics named `cv` or with `cv` as a word, e.g. `temp_cv`, and `cv()` itself) on kelvin when the data are in C or F, announces it, and records `ratio_unit = "K"` (labels say "computed in K"); a temperature with no recorded unit warns | a CV needs a scale with a true zero: in C it depends on the scale and divides by zero near 0 C (Jan's request) |
| 2026-10-20 | §15 | `main` on GitHub is protected: a pull request is needed and R-CMD-check must pass; no approvals are required (one maintainer), no force pushes or deletion | CI is green on every chunk; keeps a broken chunk out of `main` |
| 2026-10-20 | §5 | Maintainer email is `jan.rossi@fao.org` | Jan's confirmation |
| 2026-10-20 | §13 | The grid runs the table steps on blocks of raster rows (`grid_apply()`), instead of separate kernel code per indicator; a `tapp()` fast path covers sums of fixed-threshold days and excess | every grid number equals the table path by construction; the fast path gives 8 to 15 times the speed where terra has a built-in |
| 2026-10-20 | §13 | `calc_threshold_day()`, `calc_percentile()`, `calc_par()` and `calc_std_index()` are S3 generics; the table code is the `default` method, which now rejects unknown arguments (`check_dots_empty()`); no raster methods for `calc_spell()` and `calc_percentile_day()` | spells and percentile days need a flag raster first; `grid_indicators()` covers them |
| 2026-10-20 | §13 | Grid layers are named `<indicator>_<period>` (`day_abv_30_sum_2021`, `spi_3_2021-07`, `day_90p_07`); the registry, the series unit and the call are kept in URL-encoded GeoTIFF tags (`c4e_grid*`); `extract_by_coord()` and `extract_by_poly()` rebuild the long table | the extracted table equals the table path, registry included |
| 2026-10-20 | §13 | `grid_controls()` builds the density window in kilometres at the raster's mean latitude on lon/lat rasters; layers on other grids are resampled onto the first (bilinear, nearest, sum by kind) | `focalMat()` takes degrees on lon/lat rasters |
| 2026-10-20 | §13 | `grid_first` in `weather_extremes()` not built | per-interview windows need daily values; extracting `grid_indicators()` serves many surveys over one raster |
| 2026-10-21 | §15 | The protection of `main` applies to admins too ("Do not allow bypassing") | chunk 12 reached `main` by a direct push that skipped the pull request |
| 2026-10-21 | §8 chunk 13 | v1 references are recorded through `v1_ref(name, expr)` in the tests, stored in one file `fixtures/v1_reference.rds` (155 kB, xz); the expression stays in the test as a record, evaluated only with `C4E_RECORD_V1=true` | one mechanism for every comparison; re-recording needs only a commit where the v1 functions exist |
| 2026-10-21 | §8 chunk 13 | Kept as internal functions, not removed: `filter_by_interview()` (used by `select_by_interview()`), `find_merge_var()` (by `merge_by_common()` and `get_poly_attr_for_point()`), `read_GAUL()` and `read_geoBoundaries()` (by `read_boundaries()`), `sum_na_check()`, `mean_na_check()`, `max_na_check()` (by the window summaries) and `to_date()` | v2 calls them; folding them in is chunk 14 work if wanted |
| 2026-10-21 | §8 chunk 13 | `inst/bench/bench-kernel.R` calls the v1 side from `climatic4economist` | the benchmark stays runnable without the v1 functions in c4e |
| 2026-10-21 | §5 | Imports are checkmate, cli, clock, dplyr, lifecycle, lubridate, purrr, rlang, SPEI, stringr, terra, tibble, tidyr, vctrs; `sf`, `exactextractr`, `furrr` are Suggests asked for with `check_installed()`; `stringi`, `tidyterra`, `raster` are gone | lighter installation; coverage weights and parallel runs are the only users of the optional packages |
| 2026-10-21 | §5, §7 | The Quarto case studies moved from `vignettes/` to `case_studies/` (build-ignored) | pkgdown would build every `.qmd` under `vignettes/` as an article, and these need external data; `vignettes/` is kept for the package articles of chunk 15 |
| 2026-10-21 | §5 | NSE column names are declared in `utils::globalVariables()` rather than rewritten with `.data$` | one place, no change to the legacy helpers' code |
| 2026-10-21 | §5 | `@family` and `@inheritParams` not added across the reference | the pkgdown index groups the topics by task; left for a later pass |
| 2026-10-21 | §5 | pkgdown builds on every pull request and publishes from `main` to the `gh-pages` branch | the workflow pushes to `gh-pages`, which the protection of `main` does not cover |
| 2026-10-21 | §7, §8 row 16 | Chunk 16 writes three case-study articles instead of porting the 20 country scripts: one country with household coordinates and division controls, several countries with `purrr::map()`, a narrow project with distances; on the bundled synthetic data, run on every build; the scripts stay in `case_studies/` | Jan's choice: fewer, maintained examples; synthetic data shows output, is checked by CI and carries no privacy risk |
| 2026-10-21 | §8 row 16 | New step function `displace_coord()` (DHS displacement: urban up to 2 km, rural up to 5 km, 1% of rural up to 10 km, kept within the administrative unit), recorded in the context and shown in labels and the codebook | sharing georeferenced survey data needs it, and the case studies teach it as part of the workflow |
| 2026-10-21 | §7, §8 row 15 | Vignettes in R Markdown, not Quarto: `vignettes/c4e.Rmd` (*Get started*, built by R CMD build) and six articles in `vignettes/articles/` (build-ignored, rendered by pkgdown) | knitr needs nothing more in CI; articles keep R CMD check fast while the website still runs every one on each pull request |
| 2026-10-21 | §8 row 15 | The `_targets.R` example is a non-run chunk in *Get started*, not a file | `targets` is not a dependency; the chunk shows the pattern where readers look for it |
| 2026-10-21 | §8 rows 16, 17 | Release on GitHub and r-universe now, CRAN later; case studies on a separate tutorial website, not in the package; the six workflow articles stay on the package site; `displace_coord()` in the package | Jan's choice: a lean package; r-universe gives `install.packages()` without CRAN's review |
| 2026-10-21 | §8 row 17 | The first release goes to GitHub only, for colleagues to test with `remotes::install_github()`; r-universe follows their feedback | Jan's choice: test with a small group before wider publication |
| 2026-10-21 | §8 row 18 | A paper in the Journal of Open Source Software (about 1,000 words, open review on GitHub, a DOI) rather than a longer journal article | presents the package and gives it a citation at little cost; reviewers test the package as the colleagues do |
| 2026-10-21 | §8 row 16 | `displace_coord()` draws the distance uniformly up to the limit and the direction uniformly (the DHS rule), moves all households of a location together, redraws a location until it lands in its own division, rebuilds coordinate identifiers (the old ones reveal the true place), and records the rule in `survey$displaced` but never the seed (the seed undoes the displacement) | privacy holds only if no trace of the true location survives |

### Open R CMD check NOTEs

- New submission; the site URL answers 404 until GitHub Pages is on.
- "unable to verify current time" and "README.md or NEWS.md cannot be
  checked without pandoc": this laptop only (no internet time server,
  pandoc not on the PATH). For pkgdown here, set
  `RSTUDIO_PANDOC="C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"`.

## How to run things on a machine without R on the PATH

```bash
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" -e 'testthat::test_local()'
```

Fixtures are rebuilt (identically, seeded) with:

```bash
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" dev/make_fixtures.R
```

To reproduce the GitHub check locally (same arguments as CI):

```bash
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran", "--ignore-vignettes"), build_args = c("--no-manual", "--no-build-vignettes"), error_on = "warning")'
```

## Session entries

### 2026-10-21 — JOSS paper draft (laptop: FAO-Win, session: Claude)
- Did: branch `joss-paper` stacked on `chunk-16-displace` (#10 open):
  `paper/paper.md` (Summary, Statement of need, State of the field, Software
  design, Research impact and AI disclosure as placeholders), `paper/paper.bib`
  (13 references), `.github/workflows/draft-pdf.yaml`, `^paper$` build-ignored.
- Found: nothing blocking; the placeholders need Jan's input.
- Next: see Next steps above.

### 2026-10-21 — chunk 16, displace_coord() (laptop: FAO-Win, session: Claude)
- Did: chunk 15 merged (#9), site checked (articles live, agent pages gone).
  Branch `chunk-16-displace` from `main`: `R/displace_coord.R`, the
  displacement in `c4e_labels()`, the printed context and the codebook,
  `tests/testthat/test-displace.R`. Plan rows 16 and 17 rewritten (see
  decisions).
- Found: coordinate identifiers from `prepare_coord()` encode the true
  coordinates, so they must be rebuilt after displacement.
- Tests: `test-displace.R` 29 expectations; full suite 1166, 0 failures;
  `rcmdcheck`: 0 errors, 0 warnings, 3 notes (two from this laptop; one
  "VignetteBuilder but no prebuilt vignette index" because CI skips
  building vignettes: build them in CI at the release).
- Next: see Next steps above.

### 2026-10-21 — chunk 15 (laptop: FAO-Win, session: Claude)
- Did: after #6 (chunk 14) and the README and title (#7, #8) were merged,
  GitHub Pages turned on (https://jmr-fao.github.io/c4e/) and the About
  panel given the website. Branch `chunk-15-articles` from `main`: knitr as
  vignette builder, *Get started* (`vignettes/c4e.Rmd`), six articles in
  `vignettes/articles/`, an Articles menu in `_pkgdown.yml`; the
  `read_boundaries()` example writes GAUL's own field names.
- Found: the miniature GAUL file in the example and the article clashed with
  the fixture's `adm_div_*` columns (terra renamed them with a warning).
- Tests: every article renders on the bundled data with no error or warning;
  `pkgdown::build_site()` builds the whole site locally (CRAN lookups stubbed,
  the FAO network blocks them); local `rcmdcheck` with CI's arguments: 0
  errors, 0 warnings, 0 notes.
- Also: the pkgdown workflow removes `CLAUDE.md` and `AGENTS.md` from its
  checkout before building (pkgdown publishes every top-level `.md`, and
  they were on the live site) and deploys with `clean: true`; the README
  logo has alt text.
- Next: see Next steps above.

### 2026-10-21 — chunk 14 (laptop: FAO-Win, session: Claude)
- Did: branch `chunk-14-hygiene` from `main` (chunk 13 merged as #5, chunk
  branches deleted). Imports pruned (see decisions), terra-only SpatVector
  helpers (`R/vect_helpers.R`), `get_poly_attr_for_point()` on
  `terra::nearest()`, `globalVariables()`, `:=` imported, 15 examples
  rewritten to run, `LICENSE.md`, logo to `man/figures/logo.png`,
  `case_studies/`, `_pkgdown.yml` (reference by task, wrappers first) and
  `.github/workflows/pkgdown.yaml`, the site URL in `DESCRIPTION`.
- Found: `merge_by_common()` on a SpatVector worked only through
  tidyterra's dplyr methods (now `vect_join()`); the tarball was 20 MB
  because of the case studies; pkgdown needs pandoc, which RStudio ships.
- Tests: 1137 expectations, 0 failures; `pkgdown::check_pkgdown()` clean;
  local `rcmdcheck` with CI's arguments: 0 errors, 0 warnings, 3 notes
  (new submission and site URL, and two that are this laptop only).
- Next: see Next steps above.

### 2026-10-21 — chunk 13 (laptop: FAO-Win, session: Claude)
- Did: confirmed `main` green on GitHub after chunk 12. Branch
  `chunk-13-v1-removal` from `main`. `v1_ref()` helper and
  `fixtures/v1_reference.rds` (21 references, recorded with the v1
  functions present and checked again from the file), committed first;
  then 32 v1 functions and 7 v1-only test files removed, v1 tests dropped
  from 10 mixed files, 8 v1 helpers made internal, links to removed
  functions turned into plain text, `data.table` out of Imports, the
  kernel benchmark pointed at `climatic4economist`.
- Found: chunk 12 reached `main` by a direct push from this folder
  (admins could bypass the protection; now they cannot). The country
  vignettes still use v1 names; they are ported in chunks 15 and 16.
- Tests: 1137 expectations, 0 failures (the v1-only tests account for the
  drop from 1389). Exports from 121 to 81.
- Next: see Next steps above.

### 2026-10-20 — chunk 12 (laptop: FAO-Win, session: Claude)
- Did: `main` protected on GitHub (pull request and R-CMD-check required);
  maintainer email `fao.org`. Branch `chunk-12-grid` from `main`.
  `R/grid_engine.R` (block engine, layout, tags, extraction restore),
  `R/grid.R` (raster methods of four step functions, `tapp()` fast path,
  `grid_indicators()`, `grid_controls()`), the indicator chain of
  `weather_extremes()` factored into `extremes_spec()` and
  `compute_extremes()`, `raster_meta()` reads a grid's series unit from its
  tags, `inst/bench/bench-grid.R`.
- Found: terra splits tag values on `=` (values are URL-encoded);
  `focalMat()` takes degrees on lon/lat rasters; `cover()` takes no number
  on terra 1.9.46 (`subst()` instead); the engine runs about 270,000 values
  a second, 80 to 125 times slower than `tapp()` for plain counts, hence
  the fast path.
- Tests: 1389+ expectations, 0 failures; `test-grid.R` checks the grid
  against the table path at the survey points for every method and
  wrapper, blocks against one block, the fast path against the engine,
  the GeoTIFF round trip under a tiny memory budget, empty cells, density
  against a hand-made `focal()`, normals and aggregated zones.
- Next: see Next steps above.

### 2026-10-20 — GitHub repository (laptop: FAO-Win, session: Claude)
- Did: created `jmr-fao/c4e` (public, empty) in the browser, reconnected
  `origin`, pushed `main` and the four chunk branches, enabled Actions,
  opened pull requests #1 to #4 stacked chunk by chunk, set the About
  topics. On `chunk-11-wrappers`: README brought up to chunk 11 with the
  R-CMD-check badge and a one-call example; the tracked root `.DS_Store`
  removed (it was already in `.gitignore`).
- Found: GitHub Desktop could not publish because `origin` pointed at a
  repository that did not exist yet; Actions starts disabled on a new
  repository and needs "Enable Actions on this repository". The `gh` CLI is
  not installed on this laptop, so the app cannot follow the pull requests.
- Tests: the README examples run and the one-call result equals the
  step-by-step chain.
- Next: see Next steps above.

### 2026-10-20 — chunk 11 (laptop: FAO-Win, session: Claude)
- Did: branch `chunk-11-wrappers` from `chunk-10-export`. `R/presets.R`
  (ten presets, `list_presets()`, preset checks against the data, the three
  `*_control()` constructors), `R/wrappers.R` (shared machinery,
  `weather_extremes()`, `climate_indices()`), `R/controls.R`
  (`static_controls()` with terrain, radii and distances;
  `time_varying_controls()` with year matching, density, log and climate
  normals). Labels for control columns in `R/labels.R`.
- Found: tidy-select arguments forwarded as `cols$x` reached `prepare_coord()`
  as expressions, not NULL (now `!!`); `vec_rbind(.names_to =)` drops the
  registry; an old `test-extract.R` expectation checked a missing column
  and passed vacuously (fixed).
- Tests: 1322 expectations, 0 failures; `test-wrappers.R` covers each
  wrapper against its step-by-step chain, every preset on a fixture, the
  mismatch error, overrides, `keep_steps`, `dry_run`, `verbose = FALSE`,
  lists of surveys, boundaries, year matching and labels. Local `rcmdcheck`
  with CI's arguments: 0 errors, 0 warnings, 4 notes, none from the new code.
- Then, on Jan's request: the kelvin safeguard for coefficients of
  variation in `calc_par()` (see decisions), with four tests in
  `test-calc-par.R`; `rcmdcheck` again 0 errors, 0 warnings, 4 notes.
- Next: see Next steps above.

### 2026-10-20 — chunk 10 (laptop: FAO-Win, session: Claude)
- Did: branch `chunk-10-export` from `chunk-9-survey`. `R/labels.R`
  (`c4e_labels()` and per-kind labels), `R/write_stata.R` (`write_stata()`
  with labels, Stata-safe names, name-length and clash checks, logical to
  0/1, `codebook = TRUE` Markdown sidecar with context, variables and
  history), `R/inspect.R` (`validate_c4e()` and `summary.c4e_tbl()` with
  print methods). Summary registry entries record their source kind.
- Found: `to_stata_format()` loses signs and decimals (see decisions); the
  first label draft ran past 80 characters.
- Tests: 37 files, 501 tests, 1240 expectations, 0 failures; new
  `test-write-stata.R` (10 tests, snapshots of every label kind, the
  checks and the summary). Local `rcmdcheck` with CI's arguments: 0
  errors, 0 warnings, 4 notes, none from the new code.
- Next: see Next steps above.

### 2026-10-20 — chunk 9 (laptop: FAO-Win, session: Claude)
- Did: branch `chunk-9-survey` from `chunk-8-std-index`. `prepare_coord()`
  (coordinate IDs, survey columns recorded), `georef_coord()` (geom and CRS
  from the metadata, CRS assumption announced), `merge_with_survey()`
  (context kept, explosion warning), `R/windows.R` (four window types,
  `window_frame()`, `expected_count()`), `R/summarise_by_interview.R`
  (`summarise_by_interview()` on the registry with coverage, dropped
  interviews reported, splitting by location; `summarise_by_period()`),
  `R/aggregate_to_adm.R`.
- Found: window summaries equal v1 `extr_day_by_interview()` and
  `extr_spell_by_interview()` on the fixtures; the coordinate IDs broke the
  ID-based matching of the saved `calc_par()` references (fixed in the
  test).
- Tests: 36 files, 491 tests, 1215 expectations, 0 failures; new
  `test-survey.R` (16 tests). Local `rcmdcheck` with CI's arguments: 0
  errors, 0 warnings, 4 notes, none from the new code.
- Next: see Next steps above.

### 2026-10-20 — chunk 8 (laptop: FAO-Win, session: Claude)
- Did: branch `chunk-8-std-index` in `c4e`. Saved v1 `calc_par()` outputs
  on the fixtures (`dev/make_references.R`,
  `tests/testthat/fixtures/v1_calc_par.rds`). `R/calc_std_index.R`:
  `calc_std_index()` (SPI/SPEI on `spi_matrix()`, several scales, water
  balance from `pet` matched by unit and date, monthly data required) and
  `calc_std_threshold()` (signed names such as `spi3_blw_-1.5`, registered
  flags that `calc_spell()` picks up). `R/calc_par.R` rewritten: wide or
  long input, `fn`/`period`, prefix from the variable, registry entries,
  splitting by unit; the v1 helpers `aggregate_by_year()` and
  `aggregate_by_month()` are gone. `test-calc-par.R` moved to the v2
  argument names.
- Found: SPI and SPEI equal v1's `compute_spi()`/`compute_spei()`; the new
  `calc_par()` equals the saved v1 outputs, including v1's warning on
  monthly data labelled by the first of the month.
- Tests: 35 files, 475 tests, 1168 expectations, 0 failures; new
  `test-std-index.R` (11 tests). Local `rcmdcheck` with CI's arguments: 0
  errors, 0 warnings, 4 notes, none from the new code.
- Next: see Next steps above.

### 2026-10-20 — rename to c4e (laptop: FAO-Win, session: Claude)
- Did: cloned `climatic4economist` at `v2-chunk-7` into `Documents/GitHub/c4e`
  (144 commits), renamed the branch to `main`, set the remote to
  `https://github.com/jmr-fao/c4e.git`. Renamed the package: `DESCRIPTION`
  (name, title, description, URLs, version `0.1.0.9000`),
  `R/c4e-package.R` (was `R/climatic4economist.R`), `c4e.Rproj`, the
  options, every `system.file(package = )` in examples and tests, cross
  references in the docs, `tests/testthat.R`, README, NEWS, `CLAUDE.md`,
  `AGENTS.md`, the CI branches, and the plan header and chunk 13 and 17
  rows.
- Found: nothing failed under the new name; R CMD check lost the title and
  description notes and gained the expected 404 for the not-yet-created
  GitHub URLs.
- Tests: 34 files, 464 tests, 1136 expectations, 0 failures. Local
  `rcmdcheck` with CI's arguments: 0 errors, 0 warnings, 4 notes.
- Next: see Next steps above.

### 2026-10-19 — chunk 7 (laptop: FAO-Win, session: Claude)
- Did: branch `v2-chunk-7` from `v2-chunk-6`. `R/indicator_helpers.R`
  (indicator frame on a units-by-dates grid, column naming, registry
  lookups, `run_indicator()` with splitting by unit), `R/calc_threshold_day.R`
  (`calc_threshold_day()` with numeric or table thresholds,
  `calc_condition()`), `R/calc_percentile.R` (`calc_percentile()` with
  `baseline` and `yearly`, `calc_percentile_day()` with tail inference and
  variable/unit checks), `R/calc_spell.R` (`calc_spell()`,
  `calc_spell_percentile()`, `calc_spell_excess()`, `calc_heatwave()`).
- Found: every v2 function equals its v1 counterpart on the fixtures at the
  first run; the decisions above record where v2 deliberately differs.
- Tests: 34 files, 464 tests, 1136 expectations, 0 failures; new
  `test-indicators.R` (16 tests, including a pipeline that types no context
  after extraction, and splitting under a 4 KB budget). Local `rcmdcheck`
  with CI's arguments: 0 errors, 0 warnings, 5 notes, none from the new code.
- Next: see Next steps above.

### 2026-10-19 — chunk 6 (laptop: FAO-Win, session: Claude)
- Did: branch `v2-chunk-6` from `v2-chunk-5`. Probed `terra::app()` and
  `SPEI::spi()` on matrices (see decisions). `R/kernel.R` (internal):
  `as_matrix_wide()`, `matrix_to_long()`, `to_long()`, `flag_threshold()`,
  `excess_threshold()`, `run_length_rows()`, `row_quantiles()`,
  `quantile_by_month()`, `lookup_by_month()`, `spi_matrix()`,
  `apply_kernel_raster()`. `inst/bench/bench-kernel.R` and
  `inst/bench/results.md`. Plan §10.2 and §13 corrected.
- Found: the kernel equals v1 exactly on the fixtures for long tables,
  flags, excess, spells, monthly percentiles, relative flags and SPI. Speed:

  | Case | Size | v1 | Kernel | Speed-up |
  |---|---|---|---|---|
  | Flags, excess, spells | 1,000 × 1,095 | 3.2 s | 0.4 s | 7× |
  | Monthly percentiles | 1,000 × 1,095 | 131 s | 1.2 s | 113× |
  | Flags, excess, spells | 10,000 × 365 | 7.6 s | 2.0 s | 4× |
  | Monthly percentiles | 10,000 × 365 | 3,608 s | 4.0 s | 915× |

  While the benchmark ran, a process check suggested it had stalled; it had
  not (the CPU reading came from the launcher process, not R's worker).
- Tests: 33 files, 448 tests, 1090 expectations, 0 failures; new
  `test-kernel.R` (11 tests). Local `rcmdcheck` with CI's arguments: 0
  errors, 0 warnings, 4 notes, none from the new code.
- Next: see Next steps above.

### 2026-10-19 — chunk 5 (laptop: FAO-Win, session: Claude)
- Did: branch `v2-chunk-5` from `v2-chunk-4`. `R/extract_helpers.R`
  (CRS check and label, missing-location report, default summary by kind,
  extraction metadata, `extract_in_blocks()`). The four extractors return
  `c4e_tbl` with the raster's context, refuse a different CRS, and record
  `spatial_agg`; `extract_by_coord()` gained `buffer`/`fn`,
  `extract_by_poly()` gained `id`, `weights = "coverage"` and a kind-based
  default, `extract_cell_by_poly()` uses exactextractr on terra and the
  divisions' own `ID_adm_div`. `raster` moved to Suggests. One v1 test
  updated: `iteration` now gives a message, not printed output.
- Found: terra sanitises attribute names when binding values, so value
  columns are now named from the layers; a template-built raster carried its
  template's context (see decisions).
- Tests: 32 files, 437 tests, 1059 expectations, 0 failures; new
  `test-extract.R` (14 tests). Local `rcmdcheck` with CI's arguments: 0
  errors, 0 warnings, 5 notes, none from the new code.
- Next: see Next steps above.

### 2026-10-19 — chunk 4 (laptop: FAO-Win, session: Claude)
- Did: branch `v2-chunk-4` from `v2-chunk-3`. Probed terra 1.9.46 metadata
  (see decisions), then `R/raster_meta.R` (`set_raster_meta()`,
  `raster_meta()`, `keep_raster_meta()`), `R/read_climate.R`
  (`read_climate()`, variable aliases, source registry with ERA5, CHIRPS,
  WFDE5, GAEZ, date detection from layer and file names, `na_value`,
  0-360 rotation), `R/aggregate_time.R`, `R/read_boundaries.R`, and
  `select_by_dates()` / `select_by_season()` as generics with raster
  methods. Fixtures regenerated with package metadata. Plan §2 updated.
- Found: terra keeps `longnames()` per data source and refuses one per
  layer; a one-cell tolerance in the 0-360 check was 180 degrees on a coarse
  grid (now a direct longitude test).
- Tests: 31 files, 423 tests, 1011 expectations, 0 failures; new
  `test-read-climate.R` (19 tests, 68 expectations). Existing selection,
  GAUL and geoBoundaries tests pass unchanged. Local `rcmdcheck` with CI's
  arguments: 0 errors, 0 warnings, 5 notes.
- Next: see Next steps above.

### 2026-10-19 — chunk 3 (laptop: FAO-Win, session: Claude)
- Did: branch `v2-chunk-3` from `v2-chunk-2`. `R/units.R`: alias table
  (spellings such as `degC`, `kg m-2 s-1`, `mm d-1`), conversion table of
  simple units used in both directions, generic rate conversion with
  per-date factors for months and years, `infer_time_step()`,
  `resolve_unit()` for thresholds, and `convert_unit()` for rasters
  (`terra::units()`, names and dates kept), `c4e_tbl` (series, registry
  columns by role, thresholds, history) and plain data frames.
  `register_unit()` and `list_units()` exported. Plan §2 updated.
- Found: the earlier "extra warnings" on first test runs were testthat's
  notices for newly created snapshots; reruns show none. Literal degree signs
  in R code fail R CMD check (see decisions).
- Tests: 30 files, 404 tests, 943 expectations, 0 failures; new
  `test-units.R` (19 tests, 75 expectations, snapshots for every error and
  announcement). K to C on the fixture raster and on the extracted wide
  table give equal values. Local `rcmdcheck` with CI's arguments: 0 errors,
  0 warnings, 5 notes.
- Next: see Next steps above.

### 2026-10-19 — chunk 2 (laptop: FAO-Win, session: Claude)
- Did: branch `v2-chunk-2` from `v2-chunk-1`. `R/c4e_meta.R`: messages
  gated by `climatic4economist.verbose` (`c4e_inform()`,
  `c4e_progress_step()`), labels with the deprecated `iteration`
  (`resolve_label()`), defaults from upstream (`c4e_default()`), conflict
  check (`check_meta_agrees()`), history (`c4e_record()`, exported
  `c4e_history()` with a print method). `resolve_key()` now reads the key
  recorded in the metadata first. `R/chunks.R`: memory budget from
  `climatic4economist.mem_limit` or half of `terra::free_RAM()` (which
  counts kilobytes, checked on this laptop), size helpers, and
  `with_chunks()` (auto / forced / off, split by unit, a list of tables
  split on the same units, progress bar, optional furrr). Options documented
  in `?climatic4economist`. Plan §1, §9.6, §12, §14 refined (see decisions).
- Found: the extra test warnings come from R 4.5.0 loading packages built
  for 4.5.3 (see Blocked). No R CMD check notes from the new code.
- Tests: 29 files, 385 tests, 868 expectations, 0 failures; new files
  `test-defaults.R` and `test-chunks.R` with snapshots of every message.
  Local `rcmdcheck` with CI's arguments: 0 errors, 0 warnings, 5 notes.
- Next: see Next steps above.

### 2026-10-19 — chunk 1 (laptop: FAO-Win, session: Claude)
- Did: confirmed the CI fix is green on GitHub (pull request run
  39225784839). Branch `v2-chunk-1` from `v2`. Probed how dplyr 1.2.1,
  tidyr and vctrs treat a tibble subclass, then wrote
  `tests/testthat/test-c4e-tbl.R` and `R/c4e_tbl.R`: constructor,
  validator, accessors, indicator registry, pruning and renaming, merge
  policy, `bind_indicators()`, and methods for `dplyr_reconstruct`,
  `dplyr_col_modify`, `dplyr_row_slice`, `group_by`, `ungroup`,
  `as_tibble`, `tbl_sum` (context line in `print()`), `[`, `[<-`, `$<-`,
  `[[<-`, `names<-`, and vctrs `vec_ptype2`/`vec_cast`. Plan §1 updated
  (see decisions).
- Found: grouped verbs and `dplyr::bind_rows()` behave differently from
  what the plan assumed (see decisions). The remaining "possible problems"
  NOTE has no entries from the new code.
- Tests: 27 files, 357 tests, 782 expectations, 0 failures; `test-c4e-tbl.R` has 103
  expectations and one snapshot (`_snaps/c4e-tbl.md`). Local `rcmdcheck`
  with CI's arguments: 0 errors, 0 warnings, 6 notes.
- Next: see Next steps above.

### 2026-10-19 — CI fix after chunk 0 (laptop: FAO-Win, session: Claude)
- Did: installed `roxygen2` 8.1.1 and `devtools` 2.5.2. Fixed the 16 help
  pages whose examples failed: most referenced objects that did not exist
  and now run on the bundled fixtures; `find_spell()` used 0/1 instead of
  TRUE/FALSE flags; `extract_by_poly()` called `ncell()` unqualified;
  `ave_dist_2shp()` is wrapped in `\dontrun` (removed in chunk 13);
  `spi_wide()`/`spei_wide()` are internal, so they lost their help pages.
  Fixed `merge_by_common()` for a list of data frames. Corrected the
  parameter docs of `extract_by_coord()`. Declared `withr` in Suggests,
  build-ignored `AGENTS.md`, made the CI job blocking, `actions/checkout@v5`.
- Found: PR 3 (`v2` → `main`) triggered the runs; the failure was R CMD
  check stopping at the first broken example, plus the `withr` WARNING.
  GitHub itself was fine.
- Tests: 26 files, 336 tests, 679 expectations, 0 failures. Local
  `rcmdcheck` with CI's arguments: 0 errors, 0 warnings, 8 notes (listed
  above).
- Next: see Next steps above.

### 2026-10-16 — chunk 0 (laptop: FAO-Win, session: Claude)
- Did: designed v2 with Jan (plan approved after seven rounds of additions:
  wrappers, presets, grid computation, memory chunking, progress, this log).
  Created branch `v2`; added `dev/PLAN_v2.md`, this log, a repo-level
  `CLAUDE.md`, build-ignore entries for `dev/`, `CLAUDE.md`, `.github/`;
  version `2.0.0.9000`; `cli`, `lifecycle`, `vctrs` in Imports and `haven` in
  Suggests; `NEWS.md`; `.github/workflows/R-CMD-check.yaml` (non-blocking
  until chunk 14); fixtures built by `dev/make_fixtures.R` into
  `inst/extdata/` (daily tmax in K and precipitation in mm/day for 2021–2023,
  monthly precipitation for 1984–2023, 20 households, 3 divisions; about
  2 MB); `tests/testthat/helper-synthetic.R` and `test-fixtures.R`.
- Found: `clock` was missing from the R 4.5 user library, so it was installed
  from CRAN. `terra::varnames()` does not survive a GeoTIFF round trip (see
  decisions). R 4.4.x installs on this laptop have no package library, so use
  R 4.5.0.
- Tests: 26 files, 334 tests, 675 expectations passed, 0 failures. One
  pre-existing warning comes from the SPEI fit in `test-compute-spei.R`.
- Next: see Next steps above.
- Commits on `v2`: `8d8e5b1` (scaffold), `4621557` (track fixtures), and
  the commit that adds this line.
