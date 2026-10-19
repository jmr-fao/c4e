# impossible conversions are refused

    Code
      unit_conversion("C", "mm")
    Condition
      Error:
      ! Can't convert "C" to "mm".
      i No conversion is registered between "C" and "mm"; add one with `register_unit()`.

---

    Code
      unit_conversion("mm/day", "mm")
    Condition
      Error:
      ! Can't convert "mm/day" to "mm".
      x One is a rate per unit of time and the other is not.

# a per-month conversion on daily data is refused

    Code
      convert_unit(pre, "mm/month")
    Condition
      Error in `convert_unit()`:
      ! Converting "mm/day" to "mm/month" needs data with time step "month"; the input's time step is "day".

# the unit to convert from is read from upstream and announced

    Code
      out <- convert_unit(wide, "C")
    Message
      Using `from = "K"` from upstream unit.

# thresholds in another unit than the data are refused

    Code
      out <- resolve_unit(NULL, meta)
    Message
      Using `unit = "C"` from upstream unit.

---

    Code
      resolve_unit("K", meta)
    Condition
      Error:
      ! `unit` is `"K"`, but the input's unit is `"C"`.
      i Thresholds are read in the data's unit. Convert the data first, e.g. with `convert_unit(x, "C")`.

