# georef_coord reads the coordinate columns and announces the CRS

    Code
      points <- georef_coord(survey_coord())
    Message
      Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs` otherwise.

# the warning counts windows with no data at all

    Code
      out <- summarise_by_interview(coord, hot_days(), interval = "1 year")
    Condition
      Warning in `summarise_by_interview()`:
      20 of 20 household windows are `NA`: less than 80% of the days have data.
      i 20 of them have no data at all (a location on cells without data, or a window outside the dates of the data).
      i Lower `min_coverage` to keep partial windows, e.g. `min_coverage = 0.5`.

# households without an interview date are reported and dropped

    Code
      out <- summarise_by_interview(coord, hot_days(), interval = "1 year")
    Message
      2 survey units have no interview date and are left out.

