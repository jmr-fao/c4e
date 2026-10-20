# every kind of indicator gets a readable label

    Code
      print(unname(labels[c("day_abv_30_sum", "C_abv_30_sum", "spell_abv_30_max",
        "spell_abv_30_n", "lag")]))
    Output
      [1] "days above 30 C, per 1-year window"                                     
      [2] "total excess above 30 C, per 1-year window"                             
      [3] "longest spell above 30 C (2+ days), per 1-year window"                  
      [4] "number of spells above 30 C (2+ days), per 1-year window"               
      [5] "periods before the interview (1 year before the interview, lags 0 to 1)"

---

    Code
      print(unname(c4e_labels(long)[c("value", "day_abv_30", "C_abv_30",
        "spell_abv_30")]))
    Output
      [1] "tmax in C, daily"                  "days above 30 C"                  
      [3] "excess above 30 C"                 "spell length above 30 C (2+ days)"
    Code
      print(unname(c4e_labels(pct)["day_90p"]))
    Output
      [1] "90th percentile of tmax in C, daily, by month"
    Code
      print(unname(c4e_labels(rel)[c("day_abv_90p", "C_abv_90p")]))
    Output
      [1] "days above the 90th percentile"        
      [2] "excess above the 90th percentile, in C"
    Code
      print(unname(c4e_labels(spi)[c("spi_3", "spi3_blw_-1.5")]))
    Output
      [1] "SPI over 3 months"            "months with SPI-3 below -1.5"

# a window summary is written with labels Stata can read

    Code
      write_stata(out, path)
    Message
      Wrote 40 rows and 8 variables to <path>.

# names Stata cannot take are refused before writing

    Code
      write_stata(long, path)
    Condition
      Error in `write_stata()`:
      ! Stata names are at most 32 characters; this column is longer: a_very_long_indicator_name_beyond_stata_limits.
      i Rename it first, e.g. with `dplyr::rename()`; the metadata follows the new name.

# validation reports empty indicators, empty units and date gaps

    Code
      print(checks)
    Message
      v duplicate rows
      x empty indicators: no value in spell_abv_30
      x units without data: 1 unit: 30.27330_-0.11150
      x date gaps: 1 unit miss dates inside their period: 30.27330_-0.11150

# summary() describes the table, its indicators and its checks

    Code
      summary(window_summary())
    Message
      c4e table: tmax [C], day, summary; key hhid; 6 indicators
      40 rows, 20 units
      Window: 1 year before the interview, lags 0 to 1
      
      Indicators:
    Output
        day_abv_30_sum    agg    missing   0.0%  mean    108.6  days above 30 C, per 1-year window
        C_abv_30_sum      agg    missing   0.0%  mean    264.5  total excess above 30 C, per 1-year window
        spell_abv_30_max  agg    missing   0.0%  mean    27.62  longest spell above 30 C (2+ days), per 1-year window
        spell_abv_30_mean agg    missing   0.0%  mean     6.15  mean spell length above 30 C (2+ days), per 1-year window
        spell_abv_30_sum  agg    missing   0.0%  mean    95.47  total spell days above 30 C (2+ days), per 1-year window
        spell_abv_30_n    agg    missing   0.0%  mean    15.93  number of spells above 30 C (2+ days), per 1-year window
    Message
      
      Checks:
      v duplicate rows
      v empty indicators
      v units without data
      v date gaps

