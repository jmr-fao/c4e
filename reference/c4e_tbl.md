# Tables that carry their context

Functions of c4e return `c4e_tbl` objects: tibbles with one extra
attribute, the *metadata*, recording the context of the data. The
context includes the key column, the variable and its unit, the time
step, the date range and the CRS. It also holds a registry describing
every indicator column, such as its threshold, direction, percentile or
spell length. Later steps of a pipeline read their defaults from it, so
a value given once does not have to be typed again.

A `c4e_tbl` behaves like any tibble. Row and column verbs (`mutate()`,
[`filter()`](https://rdrr.io/r/stats/filter.html), `select()`,
`rename()`, joins, `bind_rows()`, `[`, grouped operations) keep the
metadata. Dropping a column removes it from the registry, and renaming a
column renames it in the registry. Verbs that change what the rows mean,
such as `summarise()` and
[`tidyr::pivot_longer()`](https://tidyr.tidyverse.org/reference/pivot_longer.html),
return a plain tibble. The package functions that summarise rebuild the
metadata themselves.

When stacking tables,
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
keeps the metadata of the first table only.
[`vctrs::vec_rbind()`](https://vctrs.r-lib.org/reference/vec_bind.html)
merges the metadata of all of them. To join indicator tables side by
side, use
[`bind_indicators()`](https://jmr-fao.github.io/c4e/reference/bind_indicators.md).

- `c4e_meta()` returns the metadata, or one field of it.

- `is_c4e_tbl()` tests for the class.

- `update_meta()` sets or clears fields. On a plain data frame it
  creates a `c4e_tbl`.

- [`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
  removes the class and the metadata.

## Usage

``` r
c4e_meta(x, field = NULL)

is_c4e_tbl(x)

update_meta(.x, ...)
```

## Arguments

- x:

  A data frame.

- field:

  Optional name of one metadata field.

- .x:

  A data frame or a `c4e_tbl`.

- ...:

  Named metadata fields to set. `NULL` clears a field.

## Value

`c4e_meta()` returns a named list, one field, or `NULL` when `x` carries
no metadata. `is_c4e_tbl()` returns `TRUE` or `FALSE`. `update_meta()`
returns a `c4e_tbl`.

## Metadata fields

- `key`: name of the column identifying the units, e.g. `ID`.

- `unit_cols`: further identifying columns, e.g. `x_cell`, `y_cell`.

- `variable`, `unit`: the base series, e.g. `"tmax"` in `"C"`.

- `time_step`: one of `"hour"`, `"day"`, `"month"`, `"year"`.

- `shape`: `"wide"` (one column per date), `"long"` (`date`, `value`),
  `"lookup"` (key by month) or `"summary"` (key, possibly by lag).

- `date_col`, `date_range`: the date column and the period covered.

- `crs`, `source`: coordinate reference system and data source.

- `indicators`: one entry per indicator column, giving its `kind`
  (`"flag"`, `"excess"`, `"spell"`, `"pct"`, `"std"`, `"par"` or
  `"agg"`) and the parameters it was computed with.

- `transform`, `spatial_agg`, `window`, `survey`, `survey_cols`,
  `history`, `label`, `id_rule`, `preset`: set by later steps of the
  pipeline.

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = c("1", "2"), value = c(28, 33)),
  key = "ID", variable = "tmax", unit = "C", time_step = "day"
)
x
#> # A tibble: 2 × 2
#> # Context:  tmax [C], day; key ID
#>   ID    value
#>   <chr> <dbl>
#> 1 1        28
#> 2 2        33
c4e_meta(x, "unit")
#> [1] "C"

# the context survives ordinary dplyr steps
dplyr::filter(x, value > 30) |> c4e_meta("variable")
#> [1] "tmax"
```
