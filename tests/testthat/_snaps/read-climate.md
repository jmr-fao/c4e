# reading announces what was found

    Code
      invisible(read_climate(fixture_file("pre_daily.tif")))
    Message
      Read pre_daily: pre [mm/day], daily, 2021-01-01 to 2023-12-31, 1095 layers (synthetic).

# daily precipitation sums to months with valid date names

    Code
      monthly <- aggregate_time(pre, "month")
    Message
      Aggregating to month with `fn = "sum"`: pre is an amount.

