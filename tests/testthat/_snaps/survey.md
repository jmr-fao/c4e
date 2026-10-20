# georef_coord reads the coordinate columns and announces the CRS

    Code
      points <- georef_coord(survey_coord())
    Message
      Taking the coordinates as longitude and latitude in "EPSG:4326"; give `crs` otherwise.

# households without an interview date are reported and dropped

    Code
      out <- summarise_by_interview(coord, hot_days(), interval = "1 year")
    Message
      2 survey units have no interview date and are left out.

