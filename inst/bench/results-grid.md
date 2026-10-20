# Grid benchmark

Run on 2026-10-20, R 4.5.0, Windows. Times in seconds, one run each, in memory.

- **engine**: `grid_indicators(above = 30, spells = FALSE)` through the block
  engine (`options(c4e.grid_fast = FALSE)`): the table steps on blocks of cells
  (days above and their excess, per year).
- **fast**: the same call on its default path, `terra::tapp()` sums.
- **tapp**: `terra::tapp(r > 30, "years", "sum")`, days above only.
- **with spells**: `grid_indicators(above = c(30, 35))` with spells, which
  needs the engine.
- **same**: the engine's day counts equal tapp's, and fast equals engine.

| cells | days | engine (s) | fast (s) | tapp (s) | engine / fast | with spells (s) | same |
|---|---|---|---|---|---|---|---|
| 2500 | 1095 | 9.47 | 1.13 | 0.07 | 8.4 | 15.39 | TRUE |
| 10000 | 365 | 10.40 | 0.70 | 0.09 | 14.9 | 20.24 | TRUE |
