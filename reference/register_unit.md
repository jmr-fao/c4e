# Add a unit conversion

Registers a conversion between two units, and optionally other spellings
of them, for the rest of the session. The conversion works in both
directions: `value_to = value_from * factor + offset`. Rates per unit of
time (e.g. `"in/day"`) do not need registering: they convert through
their numerator.

## Usage

``` r
register_unit(from, to, factor = 1, offset = 0, aliases = NULL)
```

## Arguments

- from, to:

  Unit names, e.g. `"in"` and `"mm"`.

- factor, offset:

  Multiplier and offset from `from` to `to`.

- aliases:

  Optional named character vector of other spellings, e.g.
  `c(inch = "in")`.

## Value

The table of registered conversions, invisibly.

## See also

[`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md),
[`list_units()`](https://jmr-fao.github.io/c4e/reference/list_units.md)

## Examples

``` r
register_unit("in", "mm", factor = 25.4, aliases = c(inch = "in"))
convert_unit(data.frame(ID = "1", value = 2), "mm", from = "inch")
#> # A tibble: 1 × 2
#> # Context:  value [mm], long; key ID
#>   ID    value
#>   <chr> <dbl>
#> 1 1      50.8
```
