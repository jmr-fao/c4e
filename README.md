<p align="center">
  <img src="man/figures/logo.png" width="200" alt="c4e logo">
</p>

# c4e

<!-- badges: start -->
[![R-CMD-check](https://github.com/jmr-fao/c4e/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jmr-fao/c4e/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Climate data for economists

c4e is built for economists working with household surveys. From the
location of each household and the date of its interview, it computes:

* **weather extremes**: hot, cold, wet and dry days beyond thresholds or
  percentiles, their spells, heatwaves and drought indices (SPI, SPEI),
  over the period before each interview;
* **spatial controls**: elevation and terrain, agro-ecological zones,
  distances to roads, markets or borders, population density and climate
  normals, at the household's location or for its administrative division.

The result is one row per household, ready to merge with the survey and
export to Stata with labelled variables.

### Built on climatic4economist

c4e builds on [climatic4economist](https://github.com/jmr-fao/climatic4economist)
(hence the name, c4e) and keeps what it does, while improving two things:

* **The flow between steps.** Tables carry their context from one step to
  the next: the variable, its unit, the time step, and the thresholds,
  percentiles and spell lengths used. A value given once is not typed
  again, and every table can print the steps that produced it.
* **The safeguards.** Units are checked and converted where they are clearly
  meant, data that do not match a preset are refused with a fix, windows
  short of data give missing values rather than zeros, large jobs are split
  to fit in memory, and a coefficient of variation of temperatures is
  computed on kelvin.

climatic4economist stays available unchanged for existing scripts.

> **Status:** under development. The design and progress are in
> `dev/PLAN_v2.md` and `dev/LOG_v2.md`.

## 📘 Features

* One call per question: `weather_extremes()`, `climate_indices()`,
  `static_controls()` and `time_varying_controls()` run the whole chain from
  a survey and a raster, with named presets (`list_presets()`), a dry run,
  and step-by-step progress
* Maps and grid panels: `grid_indicators()` and `grid_controls()`
  compute the same indicators and controls for every cell of a raster,
  block by block, and write GeoTIFFs that keep their context
* Read climate rasters with their dates, unit and variable (ERA5, CHIRPS,
  WFDE5, GAEZ and your own sources)
* Convert units, including rates per day, month or year
* Extract at survey locations, buffers, polygons or cells, with CRS checks
* Daily extremes: thresholds, percentiles, spells, heatwaves, custom
  conditions
* Standardised indices (SPI, SPEI) and climatic parameters, with
  coefficients of variation of temperatures computed on kelvin
* Window summaries before each interview: lags, seasons, fixed periods,
  time since an event, with a minimum coverage
* Stata export with variable labels and a codebook; table checks and
  summaries
* Memory-aware: large jobs split automatically, with progress messages

## 📥 Installation

```r
remotes::install_github("jmr-fao/c4e")
```

## 🚀 In one call

```r
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)

hot <- c4e::weather_extremes(
  survey,
  system.file("extdata", "tmax_daily.tif", package = "c4e"),
  id = hhid, interview = interview,
  preset = "heat"                 # days above 30 and 35 C, and their spells
)

c4e::c4e_history(hot)             # the equivalent step-by-step chain
c4e::write_stata(hot, "hot_days.dta", codebook = TRUE)
```

## 🔧 Step by step

```r
tmax <- c4e::read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))

coord  <- c4e::prepare_coord(survey, lat_var = lat, lon_var = lon,
                             id = hhid, interview = interview)
points <- c4e::georef_coord(coord)

hot_days <- c4e::extract_by_coord(tmax, points) |>
  c4e::convert_unit("C") |>
  c4e::calc_threshold_day(above = c(30, 35)) |>
  c4e::calc_spell() |>
  c4e::summarise_by_interview(coord, x = _, window = c4e::window_lag("1 year"))
```

## 🔁 Coming from climatic4economist

c4e does what climatic4economist did, with new names and a few changes in
behaviour. climatic4economist stays available, so existing scripts keep
working.

| climatic4economist | c4e |
|---|---|
| `find_extr_abs_day()` | `calc_threshold_day()` |
| `calc_pct_day()` | `calc_percentile()` |
| `find_extr_rel_day()` | `calc_percentile_day()` |
| `find_spell()` | `calc_spell()` |
| `calc_pct_spell()` | `calc_spell_percentile()` |
| `find_extr_spell_rel()` | `calc_spell_excess()` |
| `find_wmo_heatwave()` | `calc_heatwave()` |
| `compute_spi()`, `compute_spei()`, `compute_water_balance()` | `calc_std_index()` |
| `extr_std_index()` | `calc_std_threshold()` |
| `extr_day_index()`, `extr_spell_index()`, `extr_day_by_interview()`, `extr_spell_by_interview()` | `summarise_by_interview()` |
| `agg_to_adm_div()` | `aggregate_to_adm()` |
| `aggregate_frequency()` | `aggregate_time()` |
| `read_GAUL()`, `read_geoBoundaries()` | `read_boundaries()` |
| `calc_par(pars = , agg_period = )` | `calc_par(fn = , period = )` |

What changes in practice:

* **Context travels with the tables.** The unit, thresholds, percentiles,
  spell length and window are recorded once and read by the next step, so
  they are no longer repeated in every call.
* **Units are checked.** A threshold in Celsius on data in kelvin is refused
  with a pointer to `convert_unit()`, instead of giving wrong counts.
* **Missing data are missing.** A window with too few days of data gives
  `NA`, not zero days.
* **Stable location identifiers.** `prepare_coord()` builds the identifier
  from the coordinates, so the same place keeps the same identifier across
  waves and files.
* **Signs are kept.** Index thresholds keep their sign in column names
  (`spi3_blw_-1.5`).

The results are the same: the tests check c4e against stored outputs of
climatic4economist. The daily indicators are also faster, measured on
synthetic data with 1,000 to 10,000 locations (`inst/bench/`):

| Indicator | climatic4economist | c4e | Faster by |
|---|---|---|---|
| Days above thresholds and their spells | 3 to 8 s | 0.4 to 2 s | 4 to 7 times |
| Monthly percentiles | 2 min to 1 hour | 1 to 4 s | 100 to 900 times |

## 📦 Dependencies

terra, SPEI, the tidyverse (dplyr, tidyr, purrr, tibble), cli, vctrs and
lifecycle. Optional: exactextractr and sf for coverage-weighted extraction
over polygons, furrr for parallel runs, and haven for the Stata export.
