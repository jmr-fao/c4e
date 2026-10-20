# daily data are refused with a pointer to monthly aggregation

    Code
      calc_std_index(extracted("pre_daily.tif", layers = 1:90), scale = 3)
    Condition
      Error in `calc_std_index()`:
      ! `calc_std_index()` needs monthly data; the input's time step is "day".
      i Aggregate the raster to months before extracting, e.g. `aggregate_time(pre, "month")`.

# SPEI from precipitation and evapotranspiration equals compute_spei()

    Code
      out <- calc_std_index(pre, scale = 3, index = "spei", pet = pet)
    Message
      Water balance: precipitation minus the absolute evapotranspiration.

# parameters are named after the variable and registered

    Code
      out <- calc_par(extracted("tmax_daily.tif"), fn = c("mean", "sd"))
    Message
      Using `prefix = "tmax"` from upstream variable.

