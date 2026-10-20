<p align="center">
  <img src="figures/Climat4Economist_Symbol_6.png" width="200">
</p>

# 🌍 c4e

<!-- badges: start -->
[![R-CMD-check](https://github.com/jmr-fao/c4e/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jmr-fao/c4e/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Climate data for economists

c4e links climate rasters to household surveys. It extracts climate data at
survey locations and administrative divisions, computes weather extreme
indicators, standardised drought indices and spatial controls, and
summarises them over the reference period before each interview, ready to
merge with survey data and export to Stata.

Tables carry their context from one step to the next: the variable, its
unit, the time step, the thresholds, percentiles and spell lengths used. A
value given once is not typed again, and every table can print the steps
that produced it.

c4e succeeds [climatic4economist](https://github.com/jmr-fao/climatic4economist),
which stays available unchanged for existing scripts.

> **Status:** under development. The design and progress are in
> `dev/PLAN_v2.md` and `dev/LOG_v2.md`.

## 📘 Features

* **One call per question**: `weather_extremes()`, `climate_indices()`,
  `static_controls()` and `time_varying_controls()` run the whole chain from
  a survey and a raster, with named presets (`list_presets()`), a dry run,
  and step-by-step progress
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

## 📦 Dependencies

terra, exactextractr, sf, SPEI, the tidyverse (dplyr, tidyr, purrr, tibble),
cli, vctrs and lifecycle; haven for the Stata export.
