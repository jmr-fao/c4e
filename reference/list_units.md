# List the unit conversions

List the unit conversions

## Usage

``` r
list_units()
```

## Value

A tibble with one row per registered conversion: `from`, `to`, `factor`
and `offset`. Each conversion also works in reverse, and rates per unit
of time convert through their numerator.

## See also

[`register_unit()`](https://jmr-fao.github.io/c4e/reference/register_unit.md),
[`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)

## Examples

``` r
list_units()
#> # A tibble: 6 × 4
#>   from  to      factor offset
#>   <chr> <chr>    <dbl>  <dbl>
#> 1 K     C        1      -273.
#> 2 C     F        1.8      32 
#> 3 m     mm    1000         0 
#> 4 m     cm     100         0 
#> 5 m     km       0.001     0 
#> 6 kg/m2 mm       1         0 
```
