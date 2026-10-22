# Household extremes, step by step

[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md)
is a chain of step functions. This article runs the chain one step at a
time, so each step can be inspected and changed. Each table carries its
context to the next step: once the raster is read, its variable, unit
and dates travel with the data, and no later step asks for them again.

``` r

library(c4e)
```

## The survey

The households need coordinates and an interview date.
[`prepare_coord()`](https://jmr-fao.github.io/c4e/reference/prepare_coord.md)
keeps one row per household and gives each distinct location an
identifier built from its coordinates, so the same place gets the same
identifier in every wave and file.

``` r

survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)

coord <- prepare_coord(survey, lat_var = lat, lon_var = lon,
                       id = hhid, interview = interview)
head(coord, 4)
#> # A tibble: 4 × 5
#> # Context:  key ID
#>   ID                hhid    lon    lat interview 
#>   <chr>             <chr> <dbl>  <dbl> <date>    
#> 1 30.87620_-0.87860 HH02   30.9 -0.879 2023-03-17
#> 2 30.45000_-0.70280 HH12   30.4 -0.703 2023-05-10
#> 3 30.85840_-0.39050 HH11   30.9 -0.390 2023-04-10
#> 4 30.77090_-0.37210 HH05   30.8 -0.372 2023-04-16
```

[`georef_coord()`](https://jmr-fao.github.io/c4e/reference/georef_coord.md)
turns the distinct locations into points. The coordinate columns and
their reference system come from the table; the assumption of longitude
and latitude in WGS84 is announced.

``` r

points <- georef_coord(coord)
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
points
#> class       : SpatVector
#> geometry    : points
#> dimensions  : 12, 1  (geometries, attributes)
#> extent      : 30.2733, 30.8974, -0.8786, 0.1409  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> names       :                ID
#> type        :             <chr>
#> values      : 30.87620_-0.87860
#>               30.45000_-0.70280
#>               30.85840_-0.39050
#>               ...
```

## The climate data

[`read_climate()`](https://jmr-fao.github.io/c4e/reference/read_climate.md)
reads a raster with its dates, variable and unit, from the file or from
the conventions of common sources (ERA5, CHIRPS, WFDE5).

``` r

tmax <- read_climate(system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
raster_meta(tmax)[c("variable", "unit", "time_step", "date_range")]
#> $variable
#> [1] "tmax"
#> 
#> $unit
#> [1] "K"
#> 
#> $time_step
#> [1] "day"
#> 
#> $date_range
#> [1] "2021-01-01" "2023-12-31"
```

The thresholds below are in Celsius, so the raster is converted first.
[`convert_unit()`](https://jmr-fao.github.io/c4e/reference/convert_unit.md)
knows the usual conversions (kelvin and Celsius, metres and millimetres,
rates per second and per day) and records the new unit.

``` r

tmax <- convert_unit(tmax, "C")
```

## Extraction

[`extract_by_coord()`](https://jmr-fao.github.io/c4e/reference/extract_by_coord.md)
reads the value of each day at each location: one row per location, one
column per day. Locations outside the raster, or on cells missing in
every layer, are reported.

``` r

extracted <- extract_by_coord(tmax, points)
extracted[1:3, 1:6]
#> # A tibble: 3 × 6
#> # Context:  tmax [C], day, wide; key ID
#>   ID                x_cell y_cell `2021-01-01` `2021-01-02` `2021-01-03`
#>   <chr>              <dbl>  <dbl>        <dbl>        <dbl>        <dbl>
#> 1 30.87620_-0.87860   30.9   -0.9         22.4         24.6         23.1
#> 2 30.45000_-0.70280   30.5   -0.7         21.8         18.8         18.5
#> 3 30.85840_-0.39050   30.9   -0.3         21.7         22.8         24.8
```

## Daily indicators

[`calc_threshold_day()`](https://jmr-fao.github.io/c4e/reference/calc_threshold_day.md)
flags the days beyond each threshold and records how far beyond they
are. The table becomes long, one row per location and day, and every new
column is registered with what it measures.

``` r

days <- calc_threshold_day(extracted, above = c(30, 35))
#> Using `unit = "C"` from upstream unit.
days[1:3, ]
#> # A tibble: 3 × 9
#> # Context:  tmax [C], day, long; key ID; 4 indicators
#>   ID      x_cell y_cell date       value day_abv_30 C_abv_30 day_abv_35 C_abv_35
#>   <chr>    <dbl>  <dbl> <date>     <dbl> <lgl>         <dbl> <lgl>         <dbl>
#> 1 30.273…   30.3   -0.1 2021-01-01  19.4 FALSE             0 FALSE             0
#> 2 30.273…   30.3   -0.1 2021-01-02  22.1 FALSE             0 FALSE             0
#> 3 30.273…   30.3   -0.1 2021-01-03  21.0 FALSE             0 FALSE             0
```

The unit was not typed: it came from the table.
[`calc_spell()`](https://jmr-fao.github.io/c4e/reference/calc_spell.md)
then finds the runs of flagged days. It needs no argument either; it
follows every flag that is registered, and takes two days as the
shortest spell.

``` r

spells <- calc_spell(days)
dplyr::filter(spells, !is.na(spell_abv_30)) |> head(3)
#> # A tibble: 3 × 11
#> # Context:  tmax [C], day, long; key ID; 6 indicators
#>   ID      x_cell y_cell date       value day_abv_30 C_abv_30 day_abv_35 C_abv_35
#>   <chr>    <dbl>  <dbl> <date>     <dbl> <lgl>         <dbl> <lgl>         <dbl>
#> 1 30.273…   30.3   -0.1 2021-04-29  31.0 TRUE          1.01  FALSE             0
#> 2 30.273…   30.3   -0.1 2021-05-11  33.2 TRUE          3.19  FALSE             0
#> 3 30.273…   30.3   -0.1 2021-05-15  30.8 TRUE          0.827 FALSE             0
#> # ℹ 2 more variables: spell_abv_30 <int>, spell_abv_35 <int>
```

## Summaries before each interview

[`summarise_by_interview()`](https://jmr-fao.github.io/c4e/reference/summarise_by_interview.md)
sums the flagged days and summarises the spells (longest, mean, total,
number) over a window before each household’s interview. The window is
an object: here the year before the interview and the year before that.

``` r

summary <- summarise_by_interview(coord, spells,
                                  window = window_lag("1 year", n_lags = 1))
print(summary, n = 4)
#> # A tibble: 40 × 14
#> # Context:  tmax [C], day, summary; key hhid; 12 indicators
#>   hhid    lag day_abv_30_sum C_abv_30_sum day_abv_35_sum C_abv_35_sum
#>   <chr> <int>          <dbl>        <dbl>          <dbl>        <dbl>
#> 1 HH01      0            103         235.              4         1.84
#> 2 HH01      1             97         248.             12        11.6 
#> 3 HH02      0            140         419.             28        24.6 
#> 4 HH02      1            136         357.              9        10.3 
#> # ℹ 36 more rows
#> # ℹ 8 more variables: spell_abv_30_max <dbl>, spell_abv_30_mean <dbl>,
#> #   spell_abv_30_sum <dbl>, spell_abv_30_n <int>, spell_abv_35_max <dbl>,
#> #   spell_abv_35_mean <dbl>, spell_abv_35_sum <dbl>, spell_abv_35_n <int>
```

Other windows are a season (`window_season(6, 9)` for June to
September), a fixed period
([`window_fixed()`](https://jmr-fao.github.io/c4e/reference/window_lag.md))
or the time since an event
([`window_since()`](https://jmr-fao.github.io/c4e/reference/window_lag.md)).
A window short of data gives a missing value rather than a zero:
`min_coverage` sets the share of days that must be present.

## What the table knows

The table keeps the steps that produced it and what every column means.
[`c4e_labels()`](https://jmr-fao.github.io/c4e/reference/c4e_labels.md)
writes a label for each column from that context, which
[`write_stata()`](https://jmr-fao.github.io/c4e/reference/write_stata.md)
uses:

``` r

c4e_history(summary)
#> <c4e history: 5 steps, 0.7 s>
#> prepare_coord(id_rule = "coordinates") |>                                                                    # 0.3 s
#>   extract_by_coord() |>                                                                                      # 0.0 s
#>   calc_threshold_day(above = c(30, 35), unit = "C") |>                                                       # 0.2 s
#>   calc_spell(min_spell = 2L) |>                                                                              # 0.0 s
#>   summarise_by_interview(window = list(type = "lag", interval = "1 year", n_lags = 1L), min_coverage = 0.8)  # 0.2 s
c4e_labels(summary)[c("day_abv_30_sum", "spell_abv_35_max")]
#>                                          day_abv_30_sum 
#>                    "days above 30 C, per 1-year window" 
#>                                        spell_abv_35_max 
#> "longest spell above 35 C (2+ days), per 1-year window"
```

``` r

write_stata(summary, file.path(tempdir(), "household_extremes.dta"))
#> Wrote 40 rows and 14 variables to
#> /tmp/RtmpBBJ832/household_extremes.dta.
```

[`validate_c4e()`](https://jmr-fao.github.io/c4e/reference/validate_c4e.md)
checks a table for duplicate rows, empty indicators, units without data
and gaps in the dates:

``` r

validate_c4e(summary)
#> ✔ duplicate rows
#> ✔ empty indicators
#> ✔ units without data
#> ✔ date gaps
```
