# Write a table to Stata with labelled variables

Writes a table as a Stata `.dta` file. Every indicator gets a variable
label saying what it measures, built from the table's context by
[`c4e_labels()`](https://jmr-fao.github.io/c4e/reference/c4e_labels.md),
so the file explains itself to whoever opens it.

## Usage

``` r
write_stata(x, path, labels = TRUE, codebook = FALSE, version = 14, ...)
```

## Arguments

- x:

  A `c4e_tbl` or a data frame.

- path:

  Path of the `.dta` file.

- labels:

  When `TRUE`, write variable labels.

- codebook:

  When `TRUE`, also write the codebook.

- version:

  Stata file version, passed to
  [`haven::write_dta()`](https://haven.tidyverse.org/reference/read_dta.html).

- ...:

  Further arguments to
  [`haven::write_dta()`](https://haven.tidyverse.org/reference/read_dta.html).

## Value

`path`, invisibly.

## Details

Column names are made valid for Stata: a minus sign becomes `m` and a
decimal point `p` (`spi3_blw_-1.5` is written `spi3_blw_m1p5`), other
characters become `_`, and date columns get an `X` in front
(`X2021_01_01`). Names longer than Stata's 32 characters, or two columns
that would get the same name, are refused before anything is written.
Logical flags are written as 0/1.

With `codebook = TRUE`, a Markdown file next to the `.dta`
(`<name>_codebook.md`) lists each variable with its original name and
label, the context of the data, and the steps that produced it
([`c4e_history()`](https://jmr-fao.github.io/c4e/reference/c4e_history.md)).

## See also

[`c4e_labels()`](https://jmr-fao.github.io/c4e/reference/c4e_labels.md)

## Examples

``` r
x <- update_meta(
  tibble::tibble(ID = "1", date = as.Date("2022-01-01") + 0:4,
                 value = c(28, 31, 33, 29, 31)),
  key = "ID", date_col = "date", shape = "long", variable = "tmax",
  unit = "C", time_step = "day")
hot <- calc_threshold_day(x, above = 30)
#> Using `unit = "C"` from upstream unit.
write_stata(hot, tempfile(fileext = ".dta"), codebook = TRUE)
#> Wrote 5 rows and 5 variables to /tmp/Rtmpf0kUEo/file22bb1d0bb02d.dta.
```
