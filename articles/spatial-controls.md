# Climatic parameters and spatial controls

Besides shocks, an analysis usually needs the place itself: its usual
climate, its terrain, its agro-ecological zone, how many people live
around it, how far it is from a road. This article builds such controls
step by step, then with the two control wrappers.

``` r

library(c4e)

survey <- read.csv(system.file("extdata", "survey.csv", package = "c4e"))
survey$interview <- as.Date(survey$interview)
coord <- prepare_coord(survey, lat_var = lat, lon_var = lon,
                       id = hhid, interview = interview)
points <- georef_coord(coord)
#> Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs`
#> otherwise.
```

## Climatic parameters

[`calc_par()`](https://jmr-fao.github.io/c4e/reference/calc_par.md)
computes statistics of each location’s series: the long-run mean and
standard deviation of temperature, or the average yearly rainfall with
`period = "year"`. The columns are named after the variable.

``` r

tmax <- read_climate(system.file("extdata", "tmax_daily.tif", package = "c4e"))
#> Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
temperature <- calc_par(extract_by_coord(convert_unit(tmax, "C"), points),
                        fn = c("mean", "sd", "cv"))
#> Using `prefix = "tmax"` from upstream variable.
#> Computing cv of tmax on kelvin, not C.
#> ℹ A coefficient of variation needs a scale with a true zero.
head(temperature, 3)
#> # A tibble: 3 × 6
#> # Context:  tmax [C], day, summary; key ID; 3 indicators
#>   ID                x_cell y_cell tmax_mean tmax_sd tmax_cv
#>   <chr>              <dbl>  <dbl>     <dbl>   <dbl>   <dbl>
#> 1 30.27330_-0.11150   30.3   -0.1      25.9    4.73  0.0158
#> 2 30.38170_-0.20260   30.3   -0.3      25.8    4.66  0.0156
#> 3 30.41290_-0.30050   30.5   -0.3      26.5    4.73  0.0158
```

A coefficient of variation divides by the mean, so it needs a scale with
a true zero: on Celsius data it is computed on kelvin, and the label
says so.

``` r

c4e_labels(temperature)[["tmax_cv"]]
#> [1] "cv of tmax (C, computed in K), all observations"
```

``` r

pre <- read_climate(system.file("extdata", "pre_daily.tif", package = "c4e"))
#> Read pre_daily: pre [mm/day], daily, 2021-01-01 to 2023-12-31, 1095 layers
#> (synthetic).
rain <- calc_par(extract_by_coord(pre, points), fn = list(total = sum), period = "year")
#> Using `prefix = "pre"` from upstream variable.
head(rain, 3)
#> # A tibble: 3 × 4
#> # Context:  pre [mm/day], day, summary; key ID; 1 indicator
#>   ID                x_cell y_cell pre_total
#>   <chr>              <dbl>  <dbl>     <dbl>
#> 1 30.27330_-0.11150   30.3   -0.1     1158.
#> 2 30.38170_-0.20260   30.3   -0.3     1288.
#> 3 30.41290_-0.30050   30.5   -0.3     1150.
```

## Layers around each location

Static layers are read at the location, or summarised within a radius
with `buffer`. How a layer is summarised follows its kind: continuous
layers are averaged, counts summed, and categories take their most
frequent value.

``` r

template <- terra::rast(system.file("extdata", "tmax_daily.tif", package = "c4e"))[[1]]
terra::time(template) <- NULL
elevation <- terra::rast(template, vals = seq(500, 1550, length.out = 36))
zones <- terra::rast(template, vals = rep(1:3, 12))

zones <- read_climate(zones, variable = "aez", kind = "categorical")
#> Read raster: aez, static, 2021-01-01 to 2021-01-01, 1 layer.
extract_by_coord(zones, points, buffer = 20000) |> head(3)
#> # A tibble: 3 × 2
#> # Context:  aez, wide; key ID
#>   ID                `2021-01-01`
#>   <chr>                    <dbl>
#> 1 30.87620_-0.87860            2
#> 2 30.45000_-0.70280            2
#> 3 30.85840_-0.39050            2
```

## Polygons

[`extract_by_poly()`](https://jmr-fao.github.io/c4e/reference/extract_by_poly.md)
summarises a raster over polygons, by the kind of the variable or with
`fn_agg`:

``` r

adm <- terra::vect(system.file("extdata", "adm_div.gpkg", package = "c4e"))
extract_by_poly(read_climate(elevation, variable = "elevation"), adm)
#> Read raster: elevation, static, 2021-01-01 to 2021-01-01, 1 layer.
#> Summarising by polygon with `fn_agg = "mean"`: elevation is a level.
#> # A tibble: 3 × 4
#> # Context:  elevation, wide; key ID_adm_div
#>   ID_adm_div adm_div_1 adm_div_2  `2021-01-01`
#>   <chr>      <chr>     <chr>             <dbl>
#> 1 1          West      West A              980
#> 2 2          East      East South         1340
#> 3 3          East      East North          800
```

## Distances

``` r

border <- terra::as.lines(adm)
calc_nearest_distance(points, border) |> head(3)
#> # A tibble: 3 × 2
#>   ID                dist_nearest_km
#>   <chr>                       <dbl>
#> 1 30.87620_-0.87860           13.4 
#> 2 30.45000_-0.70280           16.7 
#> 3 30.85840_-0.39050            1.05
```

## In one call: static controls

[`static_controls()`](https://jmr-fao.github.io/c4e/reference/static_controls.md)
combines the layers, the terrain measures derived from elevation,
several radii and the distances, one row per household:

``` r

static <- static_controls(survey, list(elevation = elevation, aez = zones),
                          id = hhid, buffer = c(0, 20000),
                          distance_to = list(border = border),
                          control = controls_control(verbose = FALSE))
print(static, n = 4)
#> # A tibble: 20 × 12
#> # Context:  summary; key hhid; 11 indicators
#>   hhid  elevation   aez slope   TRI roughness elevation_20km aez_20km slope_20km
#>   <chr>     <dbl> <dbl> <dbl> <dbl>     <dbl>          <dbl>    <dbl>      <dbl>
#> 1 HH01        560     3 0.473  142.       420            650        3      0.473
#> 2 HH02       1520     2 0.473  142.       420           1450        2      0.473
#> 3 HH03        920     3 0.473  142.       420            905        2      0.473
#> 4 HH04        890     2 0.473  142.       420            815        2      0.473
#> # ℹ 16 more rows
#> # ℹ 3 more variables: TRI_20km <dbl>, roughness_20km <dbl>,
#> #   dist_border_km <dbl>
c4e_labels(static)[c("aez_20km", "dist_border_km")]
#>                              aez_20km                        dist_border_km 
#>            "mode of aez within 20 km" "distance to the nearest border (km)"
```

## In one call: time-varying controls

Layers that change from year to year, such as population, are matched to
the year of each survey; `match = "previous_year"` uses only data from
before the interview. Count layers also get their density.

``` r

pop <- terra::rast(template, nlyrs = 3, vals = rep(c(100, 200, 300), each = 36))
terra::time(pop) <- as.Date(c("2021-01-01", "2022-01-01", "2023-01-01"))

controls <- time_varying_controls(survey, list(pop = pop), id = hhid,
                                  interview = interview, match = "previous_year",
                                  climate = list(tmax = system.file("extdata", "tmax_daily.tif",
                                                                    package = "c4e")),
                                  stats = c("mean", "sd"),
                                  control = controls_control(verbose = FALSE))
print(controls, n = 4)
#> # A tibble: 20 × 7
#> # Context:  summary; key hhid; 4 indicators
#>   hhid  survey_year   pop pop_year pop_density tmax_mean tmax_sd
#>   <chr>       <int> <dbl>    <int>       <dbl>     <dbl>   <dbl>
#> 1 HH01         2023   200     2022       0.406      300.    4.73
#> 2 HH02         2023   200     2022       0.406      301.    4.65
#> 3 HH03         2023   200     2022       0.406      300.    4.67
#> 4 HH04         2023   200     2022       0.406      299.    4.71
#> # ℹ 16 more rows
```
