# Kernel benchmark

Run on 2026-10-19, R 4.5.0, Windows. Times in seconds, one run each, including building the long result.

- **absolute**: flags and excess above 30 and 35, then spells of at least 2 days
  (`find_extr_abs_day()` + `find_spell()` against the kernel).
- **percentile**: monthly 90th and 95th percentiles (`calc_pct_day()` against
  `quantile_by_month()`).

| case | units | days | v1 (s) | kernel (s) | speed-up | same result |
|---|---|---|---|---|---|---|
| absolute | 1000 | 1095 | 3.24 | 0.44 | 7.3 | TRUE |
| percentile | 1000 | 1095 | 131.10 | 1.16 | 113.1 | TRUE |
| absolute | 10000 | 365 | 7.60 | 1.95 | 3.9 | TRUE |
| percentile | 10000 | 365 | 3608.39 | 3.95 | 914.7 | TRUE |
