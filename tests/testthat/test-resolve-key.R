# A minimal wide weather table, keyed by whichever column name is asked for.
wide_df <- function(key = "ID") {
    df <- data.frame(
        k = c("1", "2"),
        `2022-01-01` = c(1, 30),
        `2022-01-02` = c(25, 2),
        `2022-02-01` = c(3, 40),
        `2022-02-02` = c(35, 4),
        check.names = FALSE
    )
    names(df)[1] <- key
    df
}

# --- resolve_key ------------------------------------------------------------

test_that("resolve_key prefers ID, then falls back to ID_adm_div", {
    expect_equal(resolve_key(data.frame(ID = 1)), "ID")
    expect_equal(resolve_key(data.frame(ID_adm_div = 1)), "ID_adm_div")
    # both present: the documented precedence decides
    expect_equal(resolve_key(data.frame(ID = 1, ID_adm_div = 2)), "ID")
})

test_that("an explicit id overrides detection and accepts any column name", {
    df <- data.frame(ID = 1, ID_adm_div = 2, village = 3)

    expect_equal(resolve_key(df, "ID_adm_div"), "ID_adm_div")
    expect_equal(resolve_key(df, "village"), "village")
})

test_that("resolve_key rejects an id that is missing or not a single string", {
    df <- data.frame(ID = 1)

    expect_error(resolve_key(df, "nope"), "not found")
    expect_error(resolve_key(df, c("ID", "ID")), "single column name")
    expect_error(resolve_key(df, 42), "single column name")
    expect_error(resolve_key(df, NA_character_), "single column name")
})

test_that("resolve_key names the caller's own argument in its errors", {
    df <- data.frame(village = 1)

    expect_error(resolve_key(df), "Provide `id`")
    expect_error(resolve_key(df, arg = "poly_id"), "Provide `poly_id`")
})

# --- the key travels through the pipeline -----------------------------------

# --- the joiners ------------------------------------------------------------

test_that("merge_with_survey matches on whichever key it finds", {
    survey <- data.frame(ID_adm_div = c("1", "2"), hhid = 1:2)
    values <- data.frame(ID_adm_div = c("1", "2"), spi = c(0.5, -0.5))

    out <- merge_with_survey(survey, values)

    expect_true("ID_adm_div" %in% names(out))
    expect_equal(nrow(out), 2L)
})

test_that("merge_with_survey says which table is missing the key", {
    survey <- data.frame(ID_adm_div = c("1", "2"), hhid = 1:2)
    values <- data.frame(other = c("1", "2"), spi = c(0.5, -0.5))

    expect_error(merge_with_survey(survey, values),
                 "not found in `new_value`")
})

# --- the five consumers added after the first pass ---------------------------

test_that("georef_coord works off ID_adm_div", {
    df <- data.frame(ID_adm_div = c("1", "2"),
                     lon = c(10, 11), lat = c(45, 46))

    v <- georef_coord(df, geom = c("lon", "lat"), crs = "EPSG:4326")

    expect_s4_class(v, "SpatVector")
    expect_true("ID_adm_div" %in% names(v))
})

test_that("the indicator chain runs on ID_adm_div without naming the key", {
    df <- wide_df("ID_adm_div")
    spells <- calc_spell(calc_threshold_day(df, above = 20), min_spell = 1)
    expect_equal(c4e_meta(spells)$key, "ID_adm_div")
    expect_setequal(unique(spells$ID_adm_div), c("1", "2"))
    pct <- calc_percentile(df, p = 0.5)
    expect_equal(c4e_meta(pct)$key, "ID_adm_div")
    expect_equal(nrow(calc_percentile_day(df, pct)), 8L)
})
