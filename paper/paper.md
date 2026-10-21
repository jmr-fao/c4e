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
    affiliation: '1'
affiliations:
  - index: 1
    name: Food and Agriculture Organization of the United Nations, Italy  # TODO: confirm the division or office
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
displaced locations, a known source of measurement error when weather is
linked to surveys [@michler2022].

The package is intended for applied economists and survey teams, who are not
necessarily specialists in geospatial data. `c4e` builds on the author's
earlier package `climatic4economist` [@climatic4economist], whose functions it
reorganises around the shared context described above.

# State of the field

Each building block of `c4e` exists elsewhere. General-purpose tools read
and extract raster data (`terra` [@terra], `exactextractr`
[@exactextractr]) and fit drought indices (`SPEI` [@spei_package]). The
extreme indices themselves are standard: `xclim` [@bourgault2023] offers a far
larger set in Python, with mature handling of units and metadata, and
`climate4R` [@iturbide2019] serves climate-science workflows in R. Closer to
applied work, `climatrends` [@desousa2023] computes temperature and rainfall
indices over windows that start on a different date for each location, and
`chirps` [@desousa2020] retrieves CHIRPS rainfall with precipitation
indices; both are organised around crop trials and a single remote data
source. `stagg` [@liddell2025] and `xagg` [@schwarzwald2024] aggregate
gridded data to polygons by calendar period, with transformations and
weights suited to climate-impact regressions. For household surveys, the
Stata module `wxsum` [@michler_wxsum] turns daily series, already extracted
for each location, into seasonal weather variables, and the World Bank's
`GeoLink` [@geolink] attaches many geospatial layers to survey files over a
single date range.

Each of these tools covers part of the work and expects its own inputs:
series already extracted for each location, a single remote source, plain
vectors, or polygons and calendar periods. An economist combining them
writes the connecting code by hand: extracting the rasters, converting
units, aligning the dates of each window, reshaping the tables and labelling
the variables for Stata. Each of these hand-offs is a place where an error
passes silently. What none of the tools combines is the survey-linkage layer
that `c4e` provides, as one pipeline with checks at every step: windows
defined by each household's interview date, extremes and drought indices
computed from the rasters, spatial controls at the location or averaged over
administrative divisions, context and units carried from one step to the
next, output prepared for Stata, and the displacement of coordinates.
Adding this layer to one of the packages above would change its
core data model, built around crop-trial points, calendar periods or a
single survey-wide date range; `c4e` instead reuses `terra`,
`exactextractr` and `SPEI` rather than reimplementing them. The same
argument led to a new package rather than an extension of the author's
`climatic4economist` [@climatic4economist], whose functions pass bare data
frames and cannot carry context from one step to the next.
`climatic4economist` remains available for existing scripts.

# Software design

The central design choice is where the context of a table lives. Keeping it
in column names, as many scripts do, is fragile and forces later steps to
parse names back into thresholds; keeping it in a separate configuration
object lets the two drift apart. `c4e` stores it in an attribute of a
subclass of the tibble, and implements the `dplyr` extension methods so that
common verbs keep it [@wickham2019]. The cost is that operations outside
`dplyr`, such as base `merge()`, drop the attribute; every package function
therefore rebuilds the context on output, and a plain data frame is upgraded
after one step when its context is given explicitly.

Defaults read from the context are announced rather than applied silently,
because silent defaults recreate the errors the context is meant to prevent;
an explicit argument that contradicts the context is refused with a pointer
to the step that resolves it, such as a unit conversion.

Indicators are computed on a matrix of locations by dates rather than on
long tables, and converted to the long, tidy form only at the end; this uses
far less memory than long tables, and jobs larger than the memory available
are split into pieces with progress messages. The results are tested to be
identical to those of `climatic4economist`.
Grid outputs reuse the same step functions on blocks of raster rows
instead of reimplementing each indicator for rasters: every cell's result
equals the result the table functions give at that location, at the cost of
speed; a faster path through `terra`'s compiled routines is kept for the
simplest indicators, and tested to give the same rasters.

Finally, the package offers two levels: step functions that each perform one
operation, and wrappers that run the whole chain with named presets of common
definitions (heat, cold, heavy rain, dry spells, drought). The wrappers record
every step, so that `c4e_history()` prints the equivalent step-by-step code:
users start with one call and can move to the steps when a project needs it.
The package reads common climate sources such as ERA5 [@hersbach2020] and
CHIRPS [@funk2015] with their dates and units.

# Research impact statement

<!-- TODO: realised impact. Projects and papers that used c4e or
climatic4economist (FAO surveys, World Bank projects, ...), with citations
or links; colleagues testing the first release. -->

The package is ready for use by others: each exported function is tested on
synthetic data shipped with the package, and the indicators that replace
`climatic4economist` functions are tested against stored outputs of that
package; continuous integration runs the tests and the package checks on
every change; and a documentation website renders, on every change, an
introduction and six worked articles that run on the bundled data. Reference
benchmarks are distributed with the source.

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
