# a specification block and progress steps are printed

    Code
      invisible(weather_extremes(survey_data(), fixture_file("tmax_daily.tif"), id = hhid,
      interview = interview, preset = "heat"))
    Message
      Using lat as `lat`.
      Using lon as `lon`.
      Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs` otherwise.
      Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers (synthetic).
      i weather_extremes (heat): tmax in K, daily, 2021-01-01 to 2023-12-31
        above 30, 35 C; spells of 2+ days
        window: 1 year before the interview
        12 locations, 20 survey units
      i Extracting tmax
      Converting "K" to "C" to read the thresholds.
      v Extracting tmax [time]
      
      i Computing indicators
      Using `unit = "C"` from upstream unit.
      v Computing indicators [time]
      
      i Summarising over the reference windows
      v Summarising over the reference windows [time]
      

# dry_run describes the plan without computing

    Code
      out <- weather_extremes(survey_data(), fixture_file("tmax_daily.tif"), id = hhid,
      interview = interview, preset = "heat", control = extremes_control(dry_run = TRUE))
    Message
      Using lat as `lat`.
      Using lon as `lon`.
      Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs` otherwise.
      Read tmax_daily: tmax [K], daily, 2021-01-01 to 2023-12-31, 1095 layers (synthetic).
      i weather_extremes (heat): tmax in K, daily, 2021-01-01 to 2023-12-31
        above 30, 35 C; spells of 2+ days
        window: 1 year before the interview
        12 locations, 20 survey units
      i Dry run: nothing computed. The steps would be:
      * extract 1095 layers at 12 locations
      * convert to C
      * indicators: above 30, 35 C; spells of 2+ days
      * summaries per household: 1 year before the interview

# a preset on the wrong variable fails with a fix

    Code
      weather_extremes(survey_data(), fixture_file("pre_daily.tif"), id = hhid,
      interview = interview, preset = "heat")
    Message
      Using lat as `lat`.
      Using lon as `lon`.
      Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs` otherwise.
      Read pre_daily: pre [mm/day], daily, 2021-01-01 to 2023-12-31, 1095 layers (synthetic).
    Condition
      Error in `weather_extremes()`:
      ! "heat" expects daily tmax in C; the data are daily pre in mm/day.
      i If the data are tmax, declare it with `read_climate(path, variable = "tmax")`; otherwise choose another preset from `list_presets()`.

