# the minimum spell length is read from upstream spells

    Code
      out <- calc_spell(long)
    Message
      Using `min_spell = 4` from upstream spell.

# relative flags equal find_extr_rel_day(), upper and lower tails

    Code
      v2 <- calc_percentile_day(wide, pct)
    Message
      Using `unit = "K"` from upstream unit.
      i Percentiles of 0.5 and above are upper thresholds, the others lower.
        Flagging above: day_90p.
        Flagging below: day_10p.

