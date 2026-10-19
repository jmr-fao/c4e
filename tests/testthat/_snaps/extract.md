# points in another CRS than the raster are refused

    Code
      extract_by_coord(fixture_raster()[[1]], points)
    Condition
      Error in `extract_by_coord()`:
      ! The raster and `coord` are in different CRS: "EPSG:4326" and "EPSG:3857".
      i Project the locations first, e.g. `terra::project(coord, raster)`.

# locations without data are reported

    Code
      out <- extract_by_coord(tmax, points)
    Condition
      Warning in `extract_by_coord()`:
      2 of 3 locations have no data in the raster.
      * 1 lies outside the raster.
      * 1 falls on cells missing in every layer.
      i Identifiers: "outside" and "missing".
      i Missing cells can be filled from their neighbours with `fill_missing_rast()`.

# large extractions run in blocks of layers with the same result

    Code
      split <- extract_by_coord(tmax, points)
    Message
      i Point extraction needs about 3.8 KB (12 rows by 40 layers); the memory budget is 1.2 KB.
        Extracting in 4 blocks of up to 13 layers.

# the summary follows the kind of variable, and is announced

    Code
      out <- extract_by_poly(zones, synthetic_adm_div())
    Message
      Summarising by polygon with `fn_agg = "mode"`: aez is categorical.

