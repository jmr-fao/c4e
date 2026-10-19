# c4e_tbl: the tibble subclass that carries pipeline context (plan §1)

# a long table of daily flags for two units, as a v2 indicator function
# would return it
flags_tbl <- function() {
    x <- tibble::tibble(
        ID          = rep(c("1", "2"), each = 3),
        date        = rep(as.Date("2022-01-01") + 0:2, 2),
        value       = c(31, 29, 33, 25, 36, 37),
        day_abv_30  = value > 30,
        C_abv_30    = pmax(value - 30, 0)
    )
    new_c4e_tbl(x, list(
        key        = "ID",
        variable   = "tmax",
        unit       = "C",
        time_step  = "day",
        shape      = "long",
        date_col   = "date",
        date_range = as.Date(c("2022-01-01", "2022-01-03")),
        indicators = list(
            day_abv_30 = new_indicator("flag", base = "value",
                                       direction = "above", threshold = 30),
            C_abv_30   = new_indicator("excess", base = "value",
                                       direction = "above", threshold = 30)
        )
    ))
}

# ==== Construction and validation ============================================

test_that("the constructor builds a tibble subclass with its metadata", {
    x <- flags_tbl()

    expect_s3_class(x, c("c4e_tbl", "tbl_df", "tbl", "data.frame"), exact = TRUE)
    expect_true(is_c4e_tbl(x))
    expect_equal(c4e_meta(x, "key"), "ID")
    expect_equal(c4e_meta(x)$unit, "C")
    expect_named(c4e_meta(x)$indicators, c("day_abv_30", "C_abv_30"))
    # unset fields exist and are NULL, so code can test them directly
    expect_true("crs" %in% names(c4e_meta(x)))
    expect_null(c4e_meta(x, "crs"))
})

test_that("plain tibbles are not c4e tables and carry no metadata", {
    x <- tibble::tibble(ID = "1")
    expect_false(is_c4e_tbl(x))
    expect_null(c4e_meta(x))
})

test_that("invalid metadata is refused with a clear message", {
    x <- tibble::tibble(ID = "1", v = 1)

    expect_error(new_c4e_tbl(x, list(colour = "red")), "Unknown metadata field")
    expect_error(new_c4e_tbl(x, list(key = "id")), "not a column")
    expect_error(new_c4e_tbl(x, list(time_step = "weekly")), "time_step")
    expect_error(new_c4e_tbl(x, list(shape = "tall")), "shape")
    expect_error(new_c4e_tbl(x, list(date_range = "2022")), "date_range")
    expect_error(
        new_c4e_tbl(x, list(indicators = list(day_abv_1 = new_indicator("flag")))),
        "not a column")
    expect_error(new_indicator("days"), "kind")
    expect_error(new_indicator("flag", direction = "up"), "direction")
})

test_that("the context line is printed under the tibble header", {
    expect_snapshot(print(flags_tbl()))
})

# ==== Metadata survives dplyr and base operations ============================

test_that("row and column verbs keep the metadata", {
    x <- flags_tbl()
    survey <- tibble::tibble(ID = c("1", "2"), hhid = c("A", "B"))
    keeps <- list(
        mutate    = dplyr::mutate(x, z = value * 2),
        filter    = dplyr::filter(x, value > 30),
        arrange   = dplyr::arrange(x, dplyr::desc(value)),
        relocate  = dplyr::relocate(x, value),
        distinct  = dplyr::distinct(x, ID, .keep_all = TRUE),
        slice     = dplyr::slice_head(x, n = 2),
        left_join = dplyr::left_join(x, survey, by = "ID"),
        brackets  = x[1:2, ],
        rds       = {
            path <- withr::local_tempfile(fileext = ".rds")
            saveRDS(x, path)
            readRDS(path)
        }
    )
    for (verb in names(keeps)) {
        out <- keeps[[verb]]
        expect_true(is_c4e_tbl(out), label = verb)
        expect_equal(c4e_meta(out)$indicators, c4e_meta(x)$indicators,
                     label = verb)
    }
})

test_that("dropping columns prunes the indicator registry", {
    x <- flags_tbl()

    expect_named(c4e_meta(dplyr::select(x, -C_abv_30))$indicators, "day_abv_30")
    expect_named(c4e_meta(x[c("ID", "date", "C_abv_30")])$indicators, "C_abv_30")

    x$day_abv_30 <- NULL
    expect_named(c4e_meta(x)$indicators, "C_abv_30")
})

test_that("dropping the key column clears the key", {
    out <- dplyr::select(flags_tbl(), -ID)
    expect_true(is_c4e_tbl(out))
    expect_null(c4e_meta(out, "key"))
})

test_that("renaming columns renames them in the metadata too", {
    x <- flags_tbl()

    out <- dplyr::rename(x, hot = day_abv_30, location = ID, day = date)
    expect_equal(c4e_meta(out, "key"), "location")
    expect_equal(c4e_meta(out, "date_col"), "day")
    expect_named(c4e_meta(out)$indicators, c("hot", "C_abv_30"))

    out <- dplyr::rename_with(x, toupper, dplyr::starts_with("day"))
    expect_named(c4e_meta(out)$indicators, c("DAY_ABV_30", "C_abv_30"))

    names(x)[names(x) == "value"] <- "tmax"
    expect_equal(c4e_meta(x)$indicators$day_abv_30$base, "tmax")
})

test_that("a lookup threshold follows its column when renamed", {
    x <- tibble::tibble(ID = "1", month = "01", day_90p = 30, day_abv_90p = TRUE)
    x <- new_c4e_tbl(x, list(key = "ID", indicators = list(
        day_90p     = new_indicator("pct", base = "value", p = 0.9),
        day_abv_90p = new_indicator("flag", direction = "above",
                                    threshold = "day_90p", p = 0.9)
    )))
    out <- dplyr::rename(x, p90 = day_90p)
    expect_equal(c4e_meta(out)$indicators$day_abv_90p$threshold, "p90")
})

test_that("grouped operations keep the metadata", {
    x <- flags_tbl()

    grouped <- dplyr::group_by(x, ID)
    expect_s3_class(grouped, "grouped_df")
    expect_true(is_c4e_tbl(grouped))

    steps <- list(
        mutate  = dplyr::mutate(grouped, anomaly = value - mean(value)),
        filter  = dplyr::filter(grouped, value > min(value)),
        arrange = dplyr::arrange(grouped, value, .by_group = TRUE),
        slice   = dplyr::slice_max(grouped, value, n = 1),
        select  = dplyr::select(grouped, ID, value, day_abv_30)
    )
    for (verb in names(steps)) {
        expect_true(is_c4e_tbl(steps[[verb]]), label = paste("grouped", verb))
        expect_s3_class(steps[[verb]], "grouped_df")
    }

    out <- grouped |>
        dplyr::mutate(anomaly = value - mean(value)) |>
        dplyr::filter(anomaly > -5) |>
        dplyr::ungroup()
    expect_true(is_c4e_tbl(out))
    expect_false(inherits(out, "grouped_df"))
    expect_equal(c4e_meta(out)$indicators, c4e_meta(x)$indicators)
})

test_that("summaries and pivots return plain tibbles", {
    # their columns no longer mean what the registry says; package functions
    # that summarise rebuild the metadata themselves
    x <- flags_tbl()
    expect_false(is_c4e_tbl(dplyr::summarise(x, n = sum(day_abv_30), .by = ID)))
    expect_false(is_c4e_tbl(
        tidyr::pivot_longer(x, c(day_abv_30, C_abv_30), values_to = "amount")))
})

test_that("as_tibble() strips the class and the metadata", {
    out <- tibble::as_tibble(flags_tbl())
    expect_s3_class(out, c("tbl_df", "tbl", "data.frame"), exact = TRUE)
    expect_null(c4e_meta(out))
})

# ==== Row binding ============================================================

test_that("binding rows of compatible tables keeps the metadata", {
    x <- flags_tbl()
    out <- dplyr::bind_rows(x[1:3, ], x[4:6, ])
    expect_true(is_c4e_tbl(out))
    expect_equal(nrow(out), 6L)
    expect_equal(c4e_meta(out)$indicators, c4e_meta(x)$indicators)

    plain <- tibble::as_tibble(x[1, ])
    expect_true(is_c4e_tbl(dplyr::bind_rows(x, plain)))
    expect_true(is_c4e_tbl(vctrs::vec_rbind(plain, x)))
})

test_that("binding rows merges the indicator registries", {
    x <- flags_tbl()
    hot_35 <- dplyr::mutate(x, day_abv_35 = value > 35) |>
        add_indicator("day_abv_35", "flag", base = "value",
                      direction = "above", threshold = 35)

    out <- vctrs::vec_rbind(x, hot_35)
    expect_setequal(names(c4e_meta(out)$indicators),
                    c("day_abv_30", "C_abv_30", "day_abv_35"))

    # dplyr::bind_rows() strips attributes before rebuilding from the first
    # table, so only the first registry survives; documented in ?c4e_tbl
    out <- dplyr::bind_rows(x, hot_35)
    expect_named(c4e_meta(out)$indicators, c("day_abv_30", "C_abv_30"))
})

# ==== update_meta() ==========================================================

test_that("update_meta() sets, clears and upgrades", {
    x <- update_meta(flags_tbl(), unit = "K", crs = "EPSG:4326")
    expect_equal(c4e_meta(x, "unit"), "K")
    expect_equal(c4e_meta(x, "crs"), "EPSG:4326")

    x <- update_meta(x, crs = NULL)
    expect_true("crs" %in% names(c4e_meta(x)))
    expect_null(c4e_meta(x, "crs"))

    plain <- update_meta(tibble::tibble(ID = "1", v = 2), key = "ID", unit = "mm")
    expect_true(is_c4e_tbl(plain))
    expect_equal(c4e_meta(plain, "key"), "ID")

    expect_error(update_meta(x, "mm"), "named")
    expect_error(update_meta(x, colour = "red"), "Unknown metadata field")
})

# ==== merge_meta() ===========================================================

test_that("merge_meta() unions registries and clears conflicting fields", {
    a <- c4e_meta(flags_tbl())
    b <- modify_meta(a, list(
        variable   = "pre",
        unit       = "mm/day",
        date_range = as.Date(c("2021-06-01", "2021-12-31")),
        source     = "chirps",
        indicators = list(day_blw_1 = new_indicator("flag", direction = "below",
                                                    threshold = 1))
    ))

    out <- merge_meta(a, b)
    expect_null(out$variable)
    expect_null(out$unit)
    expect_equal(out$time_step, "day")
    expect_equal(out$date_range, as.Date(c("2021-06-01", "2022-01-03")))
    expect_equal(out$source, "chirps")
    expect_setequal(names(out$indicators),
                    c("day_abv_30", "C_abv_30", "day_blw_1"))

    expect_identical(merge_meta(a, NULL), a)
    expect_identical(merge_meta(NULL, a), a)
})

test_that("strict merging refuses different keys and reports clashes", {
    a <- c4e_meta(flags_tbl())
    expect_error(merge_meta(a, modify_meta(a, list(key = "ID_adm_div")),
                            strict = TRUE),
                 "different columns")

    other <- modify_meta(a, list(indicators = list(
        day_abv_30 = new_indicator("flag", direction = "above", threshold = 31))))
    expect_warning(out <- merge_meta(a, other, strict = TRUE),
                   "defined differently")
    expect_equal(out$indicators$day_abv_30$threshold, 30)

    expect_message(merge_meta(a, modify_meta(a, list(unit = "K")), strict = TRUE),
                   "unit")
})

# ==== bind_indicators() ======================================================

test_that("bind_indicators() joins indicator tables on key and date", {
    flags <- flags_tbl()
    spells <- flags |>
        dplyr::transmute(ID, date, value, spell_abv_30 = c(NA, NA, NA, NA, NA, 2L)) |>
        add_indicator("spell_abv_30", "spell", base = "day_abv_30",
                      direction = "above", threshold = 30, min_spell = 2)

    out <- bind_indicators(flags, spells)
    expect_true(is_c4e_tbl(out))
    expect_equal(nrow(out), 6L)
    # `value` is base data shared by both: kept once, no .x / .y suffixes
    expect_false(any(grepl("\\.(x|y)$", names(out))))
    expect_named(c4e_meta(out)$indicators,
                 c("day_abv_30", "C_abv_30", "spell_abv_30"))

    # a list works the same as separate arguments
    expect_equal(bind_indicators(list(flags, spells)), out)
})

test_that("bind_indicators() refuses the same indicator in two tables", {
    flags <- flags_tbl()
    expect_error(bind_indicators(flags, flags), "day_abv_30")
})

test_that("bind_indicators() needs a shared key", {
    a <- tibble::tibble(ID = "1", x = 1)
    b <- tibble::tibble(other = "1", y = 2)
    expect_error(bind_indicators(a, b), "no column")
})

# ==== With the synthetic fixtures ============================================

test_that("a table extracted from the fixtures keeps its context through a typical chain", {
    survey <- synthetic_survey() |>
        prepare_coord(lat_var = lat, lon_var = lon)
    points <- georef_coord(survey, geom = c("lon", "lat"), crs = "EPSG:4326")
    tmax <- extract_by_coord(synthetic_daily("tmax")[[1:10]], points) |>
        update_meta(key = "ID", unit_cols = c("x_cell", "y_cell"),
                    variable = "tmax", unit = "K", time_step = "day",
                    shape = "wide", crs = "EPSG:4326")

    out <- tmax |>
        dplyr::filter(y_cell > -0.5) |>
        dplyr::select(-x_cell) |>
        dplyr::left_join(dplyr::distinct(survey, ID, hhid), by = "ID",
                         relationship = "one-to-many")

    expect_true(is_c4e_tbl(out))
    expect_equal(c4e_meta(out, "unit"), "K")
    expect_equal(c4e_meta(out, "unit_cols"), "y_cell")
})
