# ==== read_season(), at survey locations ====================================

test_that("ASIS bounds are attached to each location, in dekads", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    out <- read_season(synthetic_survey(), "asis", season = 1, path = root)

    expect_s3_class(out, "tbl_df")
    expect_true(all(c("sos", "mos", "eos") %in% names(out)))
    expect_equal(attr(out, "season_unit"), "dekad")
    ## The cropland layer is whole over the top of the grid, where the survey
    ## locations are, so every one of them gets the season.
    expect_true(all(out$sos %in% c(4, NA)))
    expect_true(all(out$eos %in% c(18, NA)))
    expect_equal(nrow(out), nrow(synthetic_survey()))
})

test_that("the second season is a different window and may cross the year", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    one <- read_season(synthetic_survey(), "asis", season = 1, path = root)
    two <- read_season(synthetic_survey(), "asis", season = 2, path = root)

    expect_false(identical(one$sos, two$sos))
    ## ASIS dekads are signed and linear from 1 January, so a second season
    ## reaching into the next year goes past 36 rather than wrapping to 4.
    expect_true(all(two$eos[!is.na(two$eos)] > 36))
})

test_that("every ASIS flag becomes NA rather than a dekad", {
    root <- withr::local_tempdir()
    make_asis_flags(root)

    out <- read_season(synthetic_survey(), "asis", season = 1, path = root)

    ## 251, 252, 253, 255 and -9999 are not seasons and must not survive as
    ## numbers: a dekad of 255 would silently become a window.
    expect_false(any(out$sos %in% c(251, 252, 253, 254, 255, -9999),
                     na.rm = TRUE))
    expect_true(anyNA(out$sos))
})

test_that("the pasture layer is a different mask from cropland", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    crop <- read_season(synthetic_survey(), "asis", season = 1,
                        land_cover = "cropland", path = root)
    past <- read_season(synthetic_survey(), "asis", season = 1,
                        land_cover = "pasture", path = root)

    expect_false(identical(crop$sos, past$sos))
})

test_that("read_season() refuses what it cannot deliver", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    expect_error(read_season(synthetic_survey(), "gaez", season = 2),
                 "second season")
    expect_error(read_season(synthetic_survey(), "asis", season = 3,
                             path = root),
                 "1 or 2")
    expect_error(read_season(data.frame(a = 1), "asis", path = root),
                 "no .*lat.* column|no .*lon.* column")
    expect_error(read_season(synthetic_survey(), "asis",
                             path = withr::local_tempdir()),
                 "Cannot find")
})

# ==== read_season_by_poly(), per administrative division ====================

test_that("each division gets a modal and a mean season", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    out <- read_season_by_poly(synthetic_adm_div(), season = 1, path = root)

    expect_equal(nrow(out), nrow(synthetic_adm_div()))
    expect_true(all(c("sos_mode", "sos_mean", "eos_mode", "eos_mean",
                      "season_share", "season_source", "cropland_share",
                      "pasture_share") %in% names(out)))
    expect_equal(attr(out, "season_unit"), "dekad")
    ## Every cell of a cover carries the same dekad in the fixture, so the
    ## mode and the mean agree and equal it.
    given <- !is.na(out$sos_mode)
    expect_equal(out$sos_mode[given], out$sos_mean[given])
})

test_that("pasture takes over where cropland is absent, and says so", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    both <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                land_cover = c("cropland", "pasture"),
                                path = root)
    crop <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                land_cover = "cropland", path = root)

    ## The fixture holes cropland over the lower half of the grid, so at
    ## least one division has to fall back.
    expect_true(any(both$season_source == "pasture", na.rm = TRUE))
    expect_true(all(both$season_source %in% c("cropland", "pasture", NA)))

    ## The fallback is what keeps those divisions in the analysis at all.
    expect_gt(sum(!is.na(both$sos_mode)), sum(!is.na(crop$sos_mode)))

    ## Where cropland governs, the bounds are cropland's.
    on_crop <- which(both$season_source == "cropland")
    expect_equal(both$sos_mode[on_crop], crop$sos_mode[on_crop])

    ## Both shares are reported whichever cover won, so the choice is auditable.
    expect_false(anyNA(both$cropland_share))
    expect_false(anyNA(both$pasture_share))
})

test_that("min_share decides when thin cropland is allowed to govern", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    lenient <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                   min_share = 0, path = root)
    strict  <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                   min_share = 1, path = root)

    ## Requiring every cell to be cropland can only move divisions onto
    ## pasture, never off it.
    expect_gte(sum(strict$season_source == "pasture", na.rm = TRUE),
               sum(lenient$season_source == "pasture", na.rm = TRUE))
})

test_that("a division with no season under either cover gets none", {
    root <- withr::local_tempdir()
    make_asis_flags(root)        # cropland is all flags for the first cells

    out <- read_season_by_poly(synthetic_adm_div(), season = 1,
                               land_cover = "cropland", path = root)

    ## A flag is not a dekad, and an empty division is NA rather than 255.
    expect_false(any(out$sos_mode %in% c(251, 252, 253, 254, 255, -9999),
                     na.rm = TRUE))
    expect_true(all(out$season_share[is.na(out$season_source)] == 0))
})

test_that("min_share gates the fallback too, not only the primary cover", {
    ## The defect this guards: gating only cropland let pasture describe a
    ## division from a single cell. ASIS's second season covers 0.2% of
    ## Niger's cells, so ungated it returned a plausible-looking window for
    ## nearly every division in a country that has no second season.
    root <- withr::local_tempdir()
    make_asis_tree(root)

    ## make_asis_tree() leaves the last three cells empty under BOTH covers
    ## and holes cropland over the lower half, so some divisions have thin
    ## pasture support and no cropland.
    lenient <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                   min_share = 0, path = root)
    strict  <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                   min_share = 1, path = root)

    ## With a full-support demand, a division kept by the lenient gate on a
    ## partial cover must be dropped, not silently moved to the other cover.
    expect_gte(sum(is.na(strict$season_source)),
               sum(is.na(lenient$season_source)))
    expect_true(all(strict$season_share[!is.na(strict$season_source)] >= 1 - 1e-9))

    ## Every surviving row's share clears the gate, whichever cover won.
    for (m in c(0.25, 0.5)) {
        out <- read_season_by_poly(synthetic_adm_div(), season = 1,
                                   min_share = m, path = root)
        kept <- !is.na(out$season_source)
        expect_true(all(out$season_share[kept] >= m - 1e-9))
    }
})

test_that("an unsupported division carries no bounds at all", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    out <- read_season_by_poly(synthetic_adm_div(), season = 1,
                               min_share = 1, path = root)
    gone <- is.na(out$season_source)
    ## Not a borrowed season, not a flag, and a share of zero.
    expect_true(all(is.na(out$sos_mode[gone])))
    expect_true(all(is.na(out$eos_mean[gone])))
    expect_true(all(out$season_share[gone] == 0))
    ## The underlying shares are still reported, so the drop is auditable.
    expect_false(anyNA(out$cropland_share))
})

test_that("read_season_by_poly() refuses what it cannot deliver", {
    root <- withr::local_tempdir()
    make_asis_tree(root)

    expect_error(read_season_by_poly(synthetic_survey(), path = root),
                 "SpatVector")
    expect_error(read_season_by_poly(synthetic_adm_div(), season = 3,
                                     path = root), "1 or 2")
    expect_error(read_season_by_poly(synthetic_adm_div(), min_share = 2,
                                     path = root), "between 0 and 1")
    expect_error(read_season_by_poly(synthetic_adm_div(), source = "gaez",
                                     path = root))
})
