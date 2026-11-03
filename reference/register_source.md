# Teach read_climate() a data source

Registers the conventions of a dataset, so
[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md)
recognises its files and records the right variable, unit, kind and
dates. Registered sources are tried before the built-in ones (`era5`,
`chirps`, `wfde5`, `gaez`), for the rest of the session.

## Usage

``` r
register_source(
  name,
  detect,
  variable = NULL,
  unit = NULL,
  kind = NULL,
  time = NULL
)
```

## Arguments

- name:

  Name of the source, e.g. `"agera5"`.

- detect:

  A regular expression matched, ignoring case, against the file names
  and layer names; or a function of the raster and its file names
  returning `TRUE` when the files belong to the source.

- variable, unit, kind:

  Conventions of the source; see Details.

- time:

  Optional function of the raster and its file names returning one date
  (or date-time) per layer, or `NULL`.

## Value

The names of the registered sources, invisibly.

## Details

Each of `variable`, `unit` and `kind` is either a fixed string or a
function of the raster and its file names (`unit` also receives the time
step) returning a string or `NULL`.

## See also

[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md),
[`list_sources()`](https://jmr-fao.github.io/c4e/reference/list_sources.md)

## Examples

``` r
register_source("agera5", detect = "AgERA5", unit = "C")
list_sources()
#> [1] "agera5" "era5"   "chirps" "wfde5"  "gaez"  
```
