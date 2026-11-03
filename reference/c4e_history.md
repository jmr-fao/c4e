# Show the steps that produced a table

Every c4e step records its name and the arguments it used, after
defaults were filled in from upstream, along with how long it took.
`c4e_history()` returns that record, and printing it shows the pipeline
as code. Data arguments, such as the raster or the survey, are not
recorded and are left out of the code.

## Usage

``` r
c4e_history(x)
```

## Arguments

- x:

  A `c4e_tbl`.

## Value

A tibble of class `c4e_history` with one row per step: `step`, `call`
(the step as code), `elapsed` (seconds) and `time`.

## Examples

``` r
x <- update_meta(tibble::tibble(ID = "1"), key = "ID")
c4e_history(x)
#> <c4e history: no recorded steps>
```
