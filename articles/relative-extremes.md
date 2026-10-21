# Relative extremes: percentiles and spells

A fixed threshold, such as 30 C, means different things in different
places. A relative threshold compares each day with what is usual for
that place and that time of year: a day is extreme when it is above the
95th percentile of the same calendar month at the same location. This
article computes such indicators for precipitation.

``` r

library(c4e)

survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon,
                       id = hhid, interview = interview)

pre <- read_climate(system.file("extdata", "pre_daily.tif", package = "c4e"))
#> Read pre_daily: pre [mm/day], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
extracted <- extract_by_coord(pre, georef_coord(coord))
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
```

## Percentiles by location and month

[`calc_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_percentile.md)
computes, for each location and calendar month, the percentiles of the
daily values. For precipitation, dry days would pull the percentiles to
zero, so days below 0.1 mm are left out: the percentiles describe wet
days. A `baseline` restricts the dates used, so a reference period can
be kept apart from the period studied.

``` r

pct <- calc_percentile(extracted, p = c(0.9, 0.95), exclude_below = 0.1,
                       baseline = c("2021-01-01", "2022-12-31"))
head(pct, 4)
#> # A tibble: 4 × 6
#> # Context:  pre [mm/day], day, lookup; key ID; 2 indicators
#>   ID                x_cell y_cell month day_90p day_95p
#>   <chr>              <dbl>  <dbl> <chr>   <dbl>   <dbl>
#> 1 30.27330_-0.11150   30.3   -0.1 01       8.80    12.0
#> 2 30.27330_-0.11150   30.3   -0.1 02      24.9     27.4
#> 3 30.27330_-0.11150   30.3   -0.1 03      18.6     18.8
#> 4 30.27330_-0.11150   30.3   -0.1 04      15.4     19.9
```

The result is a lookup table: one row per location and month. It records
which percentile each column holds and which days it was computed on.

## Days beyond the percentiles

[`calc_percentile_day()`](https://jmr-fao.github.io/c4e/reference/calc_percentile_day.md)
compares each day with its location’s percentile for that month. The
direction follows the percentile: above for high ones, below for low
ones.

``` r

days <- calc_percentile_day(extracted, pct)
#> Using `unit = "mm/day"` from upstream unit.
#> ℹ Percentiles of 0.5 and above are upper thresholds, the others lower.
#>   Flagging above: day_90p and day_95p.
dplyr::filter(days, day_abv_95p) |> head(3)
#> # A tibble: 3 × 9
#> # Context:  pre [mm/day], day, long; key ID; 4 indicators
#>   ID           x_cell y_cell date       value day_abv_90p mm_abv_90p day_abv_95p
#>   <chr>         <dbl>  <dbl> <date>     <dbl> <lgl>            <dbl> <lgl>      
#> 1 30.27330_-0…   30.3   -0.1 2021-01-09  17.8 TRUE              9.00 TRUE       
#> 2 30.27330_-0…   30.3   -0.1 2021-03-28  19.1 TRUE              0.5  TRUE       
#> 3 30.27330_-0…   30.3   -0.1 2021-04-22  83.7 TRUE             68.3  TRUE       
#> # ℹ 1 more variable: mm_abv_95p <dbl>
```

`mm_abv_95p` is how far above the percentile each day is, in
millimetres: the excess rainfall.

## Spells and their length

Spells of days above the percentile work as for fixed thresholds.
[`calc_spell_percentile()`](https://jmr-fao.github.io/c4e/reference/calc_spell_percentile.md)
then asks how long a spell usually is, by location and month, and
[`calc_spell_excess()`](https://jmr-fao.github.io/c4e/reference/calc_spell_excess.md)
counts the days by which each spell goes beyond that usual length.

``` r

spells <- calc_spell(days, min_spell = 2)
spell_pct <- calc_spell_percentile(spells, p = 0.9)
#> Using `min_spell = 2` from upstream spell.
spell_excess <- calc_spell_excess(spells, spell_pct)
names(spell_excess)
#>  [1] "ID"                "x_cell"            "y_cell"           
#>  [4] "date"              "value"             "day_abv_90p"      
#>  [7] "mm_abv_90p"        "day_abv_95p"       "mm_abv_95p"       
#> [10] "spell_abv_90p"     "spell_abv_95p"     "spell_abv_90p_90p"
#> [13] "spell_abv_95p_90p"
```

## Before each interview

The window summaries treat every indicator by its kind: days are
counted, excesses summed, spells summarised.

``` r

summary <- summarise_by_interview(coord, spell_excess, window = window_lag("1 year"))
print(summary, n = 4)
#> # A tibble: 20 × 16
#> # Context:  pre [mm/day], day, summary; key hhid; 14 indicators
#>   hhid    lag day_abv_90p_sum mm_abv_90p_sum day_abv_95p_sum mm_abv_95p_sum
#>   <chr> <int>           <dbl>          <dbl>           <dbl>          <dbl>
#> 1 HH01      0              20           229.              14          120. 
#> 2 HH02      0              12           101.               9           36.4
#> 3 HH03      0              13           192.              10          137. 
#> 4 HH04      0              25           267.              18          169. 
#> # ℹ 16 more rows
#> # ℹ 10 more variables: spell_abv_90p_max <dbl>, spell_abv_90p_mean <dbl>,
#> #   spell_abv_90p_sum <dbl>, spell_abv_90p_n <int>, spell_abv_95p_max <dbl>,
#> #   spell_abv_95p_mean <dbl>, spell_abv_95p_sum <dbl>, spell_abv_95p_n <int>,
#> #   spell_abv_90p_90p_sum <dbl>, spell_abv_95p_90p_sum <dbl>
c4e_labels(summary)[c("day_abv_95p_sum", "mm_abv_95p_sum")]
#>                                                        day_abv_95p_sum 
#>                    "days above the 95th percentile, per 1-year window" 
#>                                                         mm_abv_95p_sum 
#> "total excess above the 95th percentile, in mm/day, per 1-year window"
```

## In one call

[`weather_extremes()`](https://jmr-fao.github.io/c4e/reference/weather_extremes.md)
does the same with a preset: `wet_days_p95` asks for the 95th and 99th
percentiles of wet days. Here the same call with `p = 0.95` and the
spell excess switched on:

``` r

wet <- weather_extremes(survey, system.file("extdata", "pre_daily.tif", package = "c4e"),
                        id = hhid, interview = interview, p = 0.95,
                        control = extremes_control(spell_excess = TRUE, verbose = FALSE))
names(wet)
#> [1] "hhid"                  "lag"                   "day_abv_95p_sum"      
#> [4] "mm_abv_95p_sum"        "spell_abv_95p_max"     "spell_abv_95p_mean"   
#> [7] "spell_abv_95p_sum"     "spell_abv_95p_n"       "spell_abv_95p_95p_sum"
```
