# Further options of the wrappers

The wrappers keep their signatures short; the less common options go in
a control list, in the style of
[`stats::glm.control()`](https://rdrr.io/r/stats/glm.control.html).

## Usage

``` r
extremes_control(
  exclude_below = NULL,
  yearly = FALSE,
  spell_excess = FALSE,
  min_coverage = 0.8,
  fill_missing = FALSE,
  keep_steps = FALSE,
  dry_run = FALSE,
  chunk = "auto",
  verbose = NULL,
  label = NULL
)

indices_control(
  min_coverage = 0.8,
  fill_missing = FALSE,
  keep_steps = FALSE,
  dry_run = FALSE,
  chunk = "auto",
  verbose = NULL,
  label = NULL,
  .parallel = FALSE
)

controls_control(
  fill_missing = TRUE,
  keep_steps = FALSE,
  dry_run = FALSE,
  verbose = NULL,
  label = NULL
)
```

## Arguments

- exclude_below:

  Values left out of percentiles, e.g. `0.1` mm for wet days. For
  precipitation percentiles it defaults to 0.1.

- yearly:

  Also compute year-round percentiles.

- spell_excess:

  Also compute spell-length percentiles and the excess of each spell
  over them, when percentiles are used.

- min_coverage:

  Share of a window that must be covered by data.

- fill_missing:

  Fill missing cells from their neighbours before extracting.

- keep_steps:

  Return a list with every intermediate table instead of the final one.

- dry_run:

  Print the plan and the estimated sizes, and stop.

- chunk:

  Splitting of large steps, passed to the steps; see
  [`?c4e`](https://jmr-fao.github.io/c4e/reference/c4e-package.md).

- verbose:

  `FALSE` silences messages and progress.

- label:

  Name shown in progress messages.

- .parallel:

  Fit SPI/SPEI series with `furrr`.

## Value

A list of class `c4e_control`.

## See also

[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md),
[`climate_indices()`](https://jmr-fao.github.io/c4e/reference/climate_indices.md),
[`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md),
[`time_varying_controls()`](https://jmr-fao.github.io/c4e/reference/time_varying_controls.md)

## Examples

``` r
extremes_control(min_coverage = 1, keep_steps = TRUE)
#> $exclude_below
#> NULL
#> 
#> $yearly
#> [1] FALSE
#> 
#> $spell_excess
#> [1] FALSE
#> 
#> $min_coverage
#> [1] 1
#> 
#> $fill_missing
#> [1] FALSE
#> 
#> $keep_steps
#> [1] TRUE
#> 
#> $dry_run
#> [1] FALSE
#> 
#> $chunk
#> [1] "auto"
#> 
#> $verbose
#> NULL
#> 
#> $label
#> NULL
#> 
#> attr(,"class")
#> [1] "c4e_control"
```
