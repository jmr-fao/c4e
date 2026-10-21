# Compare hierarchical administrative names between two datasets

This function compares sets of administrative unit names between two
datasets at a given hierarchical level. For each parent administrative
unit at the previous level, it identifies names that are present in one
dataset but not the other.

## Usage

``` r
compare_adm_div(x, y, level = 1)
```

## Arguments

- x:

  A data frame or tibble containing administrative unit names. Must
  include a column named `adm_div_<level>` and, if `level > 1`, columns
  `adm_div_1, ..., adm_div_(level - 1)`.

- y:

  A data frame or tibble with the same structure as `x`.

- level:

  Integer scalar. Administrative level to compare. Must correspond to a
  column `adm_div_<level>`. If greater than 1, grouping is performed by
  the full chain of ancestor columns
  `adm_div_1, ..., adm_div_(level - 1)`, not just the immediate parent.

## Value

A tibble with one row per parent administrative unit combination
containing:

- level:

  The level of comparison

- parent:

  The parent administrative unit chain, concatenated with `" || "` when
  `level > 1` (or `"ALL"` for level 1)

- x_only:

  Character vector of names present only in `x`

- y_only:

  Character vector of names present only in `y`

## Details

The comparison is hierarchical:

- `level = 1`: global comparison (all observations grouped together)

- `level > 1`: comparison is performed within each unique combination of
  `adm_div_1, ..., adm_div_(level - 1)`

For each parent group, the function returns:

- names present only in `x`

- names present only in `y`

The parent key is constructed by concatenating all ancestor
administrative levels using " \|\| " as a separator. This means two
units at the same level sharing a name (e.g. two districts both called
"Central") will only be treated as a match if their entire ancestor
chain is identical — a "Central" district under Region A / Province X is
never pooled with a "Central" district under Region A / Province Y, or
under an entirely different region.

Internally, the function:

- concatenates ancestor columns into a single `parent` key

- selects unique combinations of parent key and name

- removes missing values in the name column

- aggregates names per parent into sorted lists

- performs a full join between datasets at the parent level

- computes set differences using
  [`setdiff()`](https://rdrr.io/r/base/sets.html)

The helper function `build_name_sets()` is used internally to construct
grouped name lists but is not exported.

## Examples

``` r
x <- data.frame(adm_div_1 = c("North", "North", "South"),
                adm_div_2 = c("Alpha", "Beta", "Gamma"))
y <- data.frame(adm_div_1 = c("North", "North", "South"),
                adm_div_2 = c("Alpha", "Betta", "Gamma"))

compare_adm_div(x, y, level = 1)
#> # A tibble: 1 × 4
#>   level parent x_only    y_only   
#>   <dbl> <chr>  <list>    <list>   
#> 1     1 ALL    <chr [0]> <chr [0]>
compare_adm_div(x, y, level = 2)
#> # A tibble: 2 × 4
#>   level parent x_only    y_only   
#>   <dbl> <chr>  <list>    <list>   
#> 1     2 North  <chr [1]> <chr [1]>
#> 2     2 South  <chr [0]> <chr [0]>
```
