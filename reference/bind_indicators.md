# Join indicator tables side by side

Joins tables of indicators computed for the same units, for example
daily flags and spell lengths, into one table. Their metadata is merged:
the indicator registries are combined and context fields that disagree,
such as two different variables, are left unset in the result. Each
indicator keeps its own description. This replaces
`purrr::reduce(tables, dplyr::full_join)`, which keeps only the first
table's registry.

## Usage

``` r
bind_indicators(..., by = NULL)
```

## Arguments

- ...:

  Data frames, or a single list of data frames.

- by:

  Optional character vector of join columns. By default, the shared
  columns among the key, the identifying columns, the date column,
  `date`, `month` and `lag`.

## Value

A `c4e_tbl`.

## Details

Columns present in both tables that are not join columns and not
indicators, such as the `value` of the base series, are taken from the
first table. The same indicator column in two tables is an error.

## Examples

``` r
flags <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:2,
                 value = c(31, 32, 29), day_abv_30 = value > 30),
  key = "ID", date_col = "date", variable = "tmax", unit = "C"
)
spells <- tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:2,
                         value = c(31, 32, 29), spell_abv_30 = c(NA, 2L, NA))
bind_indicators(flags, spells)
#> # A tibble: 3 × 5
#> # Context:  tmax [C]; key ID
#>   ID    date       value day_abv_30 spell_abv_30
#>   <chr> <date>     <dbl> <lgl>             <int>
#> 1 1     2022-01-01    31 TRUE                 NA
#> 2 1     2022-01-02    32 TRUE                  2
#> 3 1     2022-01-03    29 FALSE                NA
```
