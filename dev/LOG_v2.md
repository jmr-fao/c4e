# climatic4economist v2 — progress log

Handoff document for v2 development. Read this first in every session, on any
laptop; the design is in `dev/PLAN_v2.md` (section numbers below refer to it).

## Status (update at the end of every session)

| # | Chunk | State | PR | Started | Done | Notes |
|---|---|---|---|---|---|---|
| 0 | Scaffold | ✔ done | | 2026-10-16 | 2026-10-19 | pushed; CI fixed on 2026-10-19 (examples, `withr`) |
| 1 | `c4e_tbl` class | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-1`; needs push and a PR into `v2` |
| 2 | Defaults, messages, history, chunking | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-2` (cut from `v2-chunk-1`); needs push and a PR into `v2` after chunk 1 |
| 3 | Units | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-3` (cut from `v2-chunk-2`); needs push and a PR into `v2` after chunk 2 |
| 4 | Raster readers | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-4` (cut from `v2-chunk-3`); needs push and a PR into `v2` after chunk 3 |
| 5 | Extraction | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-5` (cut from `v2-chunk-4`); needs push and a PR into `v2` after chunk 4 |
| 6 | Matrix kernel | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-6` (cut from `v2-chunk-5`); needs push and a PR into `v2` after chunk 5 |
| 7 | Daily indicators | 🔄 in progress | | 2026-10-19 | | complete on branch `v2-chunk-7` (cut from `v2-chunk-6`); needs push and a PR into `v2` after chunk 6 |
| 8 | Standardised indices and parameters | ☐ | | | | |
| 9 | Survey side | ☐ | | | | |
| 10 | Export and inspection | ☐ | | | | |
| 11 | Wrappers and presets | ☐ | | | | |
| 12 | Grid methods and wrappers | ☐ | | | | |
| 13 | Deprecations and removals | ☐ | | | | |
| 14 | Package hygiene | ☐ | | | | |
| 15 | Quick start and canonical vignettes | ☐ | | | | |
| 16 | Country case studies | ☐ | | | | |
| 17 | Release 2.0.0 | ☐ | | | | |

States: ☐ not started · 🔄 in progress · 👀 in review (PR open) · ✔ done · ⛔ blocked

**Current chunk:** chunks 1 to 7 are done locally and waiting for review.
Each branch was cut from the previous one (`v2-chunk-1` → ... →
`v2-chunk-7`), so each contains the chunks before it.

**Next steps (in order):**
1. Jan: push `v2-chunk-1` to `v2-chunk-7`. Open the pull requests into `v2`
   one at a time, in order, merging each once R-CMD-check is green, so each
   shows only its own commits. Mark each chunk done here once merged.
2. Next chunk: 8, standardised indices and parameters (plan §8 row 8):
   `calc_std_index()` on `spi_matrix()` (SPI/SPEI, the water balance matched
   by key and date), `calc_std_threshold()` (keeps the minus sign, reads wide
   or long input through `indicator_frame()`), `calc_par()` with `prefix`
   from the variable. Then chunk 9 (survey side) can use the registry the
   indicator functions now write.
3. New step functions reuse `R/indicator_helpers.R`: `indicator_frame()`
   (wide or long input onto a units-by-dates grid), `frame_matrix()`,
   `finish_frame()` and `run_indicator()` (splitting by unit, history
   recorded once).
4. Step functions written from chunk 3 on follow this pattern:
   `meta <- c4e_meta(x) %||% empty_meta()`, `started <- Sys.time()`,
   resolve each argument with `c4e_default()`, announce with
   `c4e_progress_step()` only when a `label` (or the deprecated `iteration`)
   is given, wrap heavy work in `with_chunks()` with a
   `mem_estimate`, and return `new_c4e_tbl(out, c4e_record(meta, fn, args,
   started))`.

**Blocked / needs Jan:**
- Pushes and pull requests of `v2-chunk-1` to `v2-chunk-7`
  (outward-facing, left to Jan).
- This laptop runs R 4.5.0 while its packages were built for R 4.5.3, so
  every fresh worker or namespace load warns "package ... was built under R
  version 4.5.3". It inflates the test-warning count (e.g. the furrr test) but
  is not a code problem. Updating R to 4.5.3 or later removes it.
- Pull request 3 merges `v2` into `main`. The plan merges `main` only at
  release (chunk 17). Keep it open as a draft tracking PR, or close it; don't
  merge it yet.

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

### Open R CMD check NOTEs (for chunk 14)

- Title not in title case; Description not complete sentences; maintainer email `fao.com`.
- Tarball is about 19.8 MB: vignette HTML and images are not build-ignored.
- All declared Imports are used since chunk 2 (`cli`, `vctrs` in chunk 1; `lifecycle` in chunk 2).
- Many "no visible binding for global variable" notes (NSE columns) and unqualified sf/sp/raster calls in `ave_*` (removed in chunk 13).
- `AGENTS.md` and `figures/` at top level (`AGENTS.md` is now build-ignored).
- `extract_cell_by_poly()` example takes about 6 s because of the `raster::brick()` conversion (removed in chunk 5).
- FAO GAUL URL in `read_GAUL.Rd` answers 403 to the checker.

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
