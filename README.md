<p align="center">
  <img src="figures/Climat4Economist_Symbol_6.png" width="200">
</p>

# 🌍 c4e

## Climate data for economists

c4e links climate rasters to household surveys. It extracts climate data at
survey locations and administrative divisions, computes weather extreme
indicators, and summarises them over the reference period before each
interview, ready to merge with survey data.

Tables carry their context from one step to the next: the variable, its
unit, the time step, the thresholds, percentiles and spell lengths used. A
value given once is not typed again, and every table can print the steps
that produced it.

c4e succeeds [climatic4economist](https://github.com/jmr-fao/climatic4economist),
which stays available unchanged for existing scripts.

> **Status:** under development. The design and progress are in
> `dev/PLAN_v2.md` and `dev/LOG_v2.md`.

## 📘 Features

* Read climate rasters with their dates, unit and variable (ERA5, CHIRPS,
  WFDE5, GAEZ and your own sources)
* Convert units, including rates per day, month or year
* Extract at survey locations, buffers, polygons or cells, with CRS checks
* Daily extremes: thresholds, percentiles, spells, heatwaves, custom
  conditions
* Memory-aware: large jobs split automatically, with progress messages

## 📥 Installation

```r
remotes::install_github("jmr-fao/c4e")
```

## 🚀 A first pipeline

```r
tmax <- c4e::read_climate(
  system.file("extdata", "tmax_daily.tif", package = "c4e"))
survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))

points <- survey |>
  c4e::prepare_coord(lat_var = lat, lon_var = lon) |>
  c4e::georef_coord(geom = c("lon", "lat"), crs = "EPSG:4326")

hot_days <- c4e::extract_by_coord(tmax, points) |>
  c4e::convert_unit("C") |>
  c4e::calc_threshold_day(above = c(30, 35)) |>
  c4e::calc_spell()

c4e::c4e_history(hot_days)
```

## 📦 Dependencies

terra, exactextractr, sf, SPEI, the tidyverse (dplyr, tidyr, purrr, tibble),
cli, vctrs and lifecycle.
