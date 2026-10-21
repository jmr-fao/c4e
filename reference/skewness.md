# Calculate sample skewness

Calculates the third standardized central moment of a numeric vector.
Missing values are removed before calculation.

## Usage

``` r
skewness(x)
```

## Arguments

- x:

  A numeric vector.

## Value

A numeric value giving the skewness of `x`.

## Details

Skewness is calculated as the third central moment divided by the cube
of the standard deviation: \$\$ \frac{\mathrm{mean}\[(x -
\bar{x})^3\]}{\mathrm{sd}(x)^3} \$\$ Missing values (`NA`) are removed
before calculation.

## Examples

``` r
x <- c(1, 2, 2, 3, 10)
skewness(x)
#> [1] 0.9737756
```
