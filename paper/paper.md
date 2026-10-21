---
title: 'c4e: Climate data for economists, linking geospatial data to household surveys'
tags:
  - R
  - economics
  - climate
  - household surveys
  - weather extremes
  - geospatial data
authors:
  - name: Jan Martin Rossi
    orcid: 0000-0000-0000-0000  # TODO: Jan's ORCID
    affiliation: 1
affiliations:
  - name: Food and Agriculture Organization of the United Nations (FAO), Rome, Italy  # TODO: confirm the division or office
    index: 1
date: 21 October 2026
bibliography: paper.bib
---

# Summary

Household surveys record where and when people were interviewed. Economists
use these two facts to ask how weather shocks and the environment shape
consumption, agricultural output, health or migration [@dell2014; @auffhammer2013].
Turning a survey's coordinates and interview dates into such variables is,
however, a long chain of steps: reading climate rasters with the right dates
and units, extracting them at each location or over each administrative
division, defining extreme days and their spells, standardising drought
indices, summarising each over the months before each interview, and
documenting what was done for the next reader.

`c4e` is an R package that performs this chain. From a survey with
coordinates and interview dates, it computes **weather extremes**, such as
days above or below absolute or relative thresholds, their spells, heatwaves
and the standardised precipitation (evapotranspiration) index
[@mckee1993; @vicente2010], over windows before each interview; and **spatial
controls**, such as terrain, agro-ecological zones, distances, population
density and climate normals, at each household's location or for its
administrative division. One function call per question returns one row per
household, ready to merge with the survey and to export to Stata with
labelled variables. The same indicators can be computed for every cell of a
raster, for maps and grid panels.

# Statement of need

Linking climate data to surveys is routine in development and environmental
economics, yet it is usually done with project-specific scripts. Three
problems recur in such scripts, and `c4e` is designed around them.

**Context is lost between steps.** A threshold of 30 is meaningful only in
degrees Celsius, a percentile only with its reference period, a count of dry
days only with its window. In scripts this context lives in variable names
and comments, and errors (thresholds applied to temperatures in kelvin,
precipitation in metres treated as millimetres, monthly data aggregated as if
daily) pass silently. In `c4e`, every table carries its context: the
variable, its unit and time step, and, for each indicator, the threshold,
percentile, spell length and window that define it. Later steps read their
defaults from this context, announce them, and refuse contradictions.
Variable labels for Stata, a codebook and the full sequence of steps are
written from the same record, so that a reviewer can see how each variable
was made.

**Safeguards are missing.** `c4e` converts units where the intent is clear and
says so, refuses data that do not match a chosen preset, gives missing values
rather than zeros when a window lacks data, computes coefficients of
variation of temperatures on an absolute scale, splits large jobs to fit in
memory, and checks tables for duplicated rows, empty indicators and gaps in
the dates.

**Privacy and sharing.** Survey coordinates identify respondents. `c4e`
displaces coordinates following the rule of the Demographic and Health
Surveys [@burgert2013], keeps each location within its administrative
division, and records the displacement in the variable labels and the
codebook, so that users of a shared file know which variables come from
displaced locations.

The package is intended for applied economists and survey teams, who are not
necessarily specialists in geospatial data. `c4e` builds on the author's
earlier package `climatic4economist` [@climatic4economist], whose functions it
reorganises around the shared context described above.

# State of the field

General-purpose tools provide the building blocks: `terra` [@terra] and
`exactextractr` [@exactextractr] read and extract raster data, `SPEI`
[@spei_package] fits standardised drought indices, and `climate4R`
[@iturbide2019] accesses and post-processes climate data for climate
science applications. None of them addresses the survey side of the problem:
windows defined by each household's interview date, indicators summarised
over those windows, administrative divisions, and output prepared for
econometric software. `c4e` uses these packages internally and adds that
layer, with presets that encode common definitions of heat, cold, heavy rain,
dry spells and drought.

# Software design

The package has three layers. Step functions (`read_climate()`,
`extract_by_coord()`, `calc_threshold_day()`, `calc_spell()`,
`summarise_by_interview()` and others) each perform one operation and return
a tibble subclass that carries the context in an attribute; `dplyr` verbs
keep it [@wickham2019]. Indicators are computed on a units-by-dates matrix
rather than on long tables, which makes the daily indicators one to three
orders of magnitude faster than the earlier package on the same data.
Wrappers (`weather_extremes()`, `climate_indices()`, `static_controls()`,
`time_varying_controls()`) run the whole chain with named presets and record
each step, so that `c4e_history()` prints the equivalent step-by-step code.
Grid methods run the same step functions on blocks of raster rows, so that
every cell's result equals the result at an extracted location, and keep the
context in GeoTIFF tags. The package works with common climate sources such
as ERA5 [@hersbach2020] and CHIRPS [@funk2015].

# Research impact statement

<!-- TODO: projects and papers that used c4e or climatic4economist (FAO
surveys, World Bank projects, ...), with citations or links. JOSS asks for
evidence that the software is used, or is likely to be used, in research. -->

# AI usage disclosure

<!-- TODO: check the wording against the current JOSS policy. -->
Large parts of the code, tests and documentation of this version were written
with the help of a generative AI coding assistant (Claude, Anthropic), under
the author's direction. The author reviewed the design, the code and the
results; every exported function is tested against reference outputs of the
earlier package on synthetic data.

# Acknowledgements

<!-- TODO: colleagues, projects and funding. -->

# References
