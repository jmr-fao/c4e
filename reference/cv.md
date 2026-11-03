# Compute Coefficient of Variation (CV)

This function calculates the coefficient of variation (CV), which is a
standardized measure of dispersion, defined as the ratio of the standard
deviation to the mean.

## Usage

``` r
cv(x, na_rm = TRUE)
```

## Arguments

- x:

  A numeric vector.

- na_rm:

  A logical value indicating whether to remove `NA` values before
  computation. Default is `TRUE`.

## Value

A numeric value representing the coefficient of variation. If `x`
contains only `NA` values or has a mean of zero, the function returns
`NA_real_`.

## Details

The ratio is meaningful only on a scale with a true zero. For
temperatures, use kelvin: in Celsius or Fahrenheit the same series gives
different values, and a mean near zero inflates the ratio without bound.
[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md)
converts C and F to kelvin for this statistic by itself.

## Examples

``` r
x <- c(10, 15, 20, 25, 30)
cv(x)  # Compute CV for a numeric vector
#> [1] 0.3952847

x_with_na <- c(10, 15, NA, 25, 30)
cv(x_with_na)  # Removes NA by default
#> [1] 0.4564355
cv(x_with_na, na_rm = FALSE)  # Returns NA if missing values exist
#> [1] NA

x_zero_mean <- c(-5, 5, -5, 5)
cv(x_zero_mean)  # Returns NA since mean is zero
#> [1] NA
```
