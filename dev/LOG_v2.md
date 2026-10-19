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
| 4 | Raster readers | ☐ | | | | |
| 5 | Extraction | ☐ | | | | |
| 6 | Matrix kernel | ☐ | | | | |
| 7 | Daily indicators | ☐ | | | | |
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

**Current chunk:** chunks 1, 2 and 3 are done locally and waiting for
review. Each branch was cut from the previous one (`v2-chunk-1` →
`v2-chunk-2` → `v2-chunk-3`), so each contains the chunks before it.

**Next steps (in order):**
1. Jan: push `v2-chunk-1`, `v2-chunk-2` and `v2-chunk-3`. Open the pull
   requests into `v2` one at a time, in order, merging each once
   R-CMD-check is green, so each shows only its own commits. Mark each chunk
   done here once merged.
2. Next chunk: 4, raster readers (plan §2, §8 row 4): `read_climate()`
   storing the variable in `terra::metags()` (see the varnames decision),
   time-step inference with `infer_time_step()` from `R/units.R`,
   `aggregate_time()`, raster methods for `select_by_dates()` /
   `select_by_season()`, `read_boundaries()`. Chunk 6 (matrix kernel) and
   the `prepare_coord` / `georef_coord` / window-object part of chunk 9 can
   also start now (plan §8 tracks B and C).
3. Indicator functions (chunk 7) call `resolve_unit(unit, meta)` from
   `R/units.R` to label thresholds and refuse a unit that contradicts the
   data.
4. Step functions written from chunk 3 on follow this pattern:
   `meta <- c4e_meta(x) %||% empty_meta()`, `started <- Sys.time()`,
   resolve each argument with `c4e_default()`, announce with
   `c4e_progress_step()`, wrap heavy work in `with_chunks()` with a
   `mem_estimate`, and return `new_c4e_tbl(out, c4e_record(meta, fn, args,
   started))`.

**Blocked / needs Jan:**
- Pushes and pull requests of `v2-chunk-1`, `v2-chunk-2` and `v2-chunk-3`
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
