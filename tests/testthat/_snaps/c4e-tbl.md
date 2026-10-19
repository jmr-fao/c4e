# the context line is printed under the tibble header

    Code
      print(flags_tbl())
    Output
      # A tibble: 6 x 5
      # Context:  tmax [C], day, long; key ID; 2 indicators
        ID    date       value day_abv_30 C_abv_30
        <chr> <date>     <dbl> <lgl>         <dbl>
      1 1     2022-01-01    31 TRUE              1
      2 1     2022-01-02    29 FALSE             0
      3 1     2022-01-03    33 TRUE              3
      4 2     2022-01-01    25 FALSE             0
      5 2     2022-01-02    36 TRUE              6
      6 2     2022-01-03    37 TRUE              7

