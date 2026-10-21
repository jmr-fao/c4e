# displace_coord() (plan §8 chunk 16)

quiet <- function(expr) suppressMessages(expr)

# how far each row moved, in metres
moved_m <- function(before, after, lon = "lon", lat = "lat") {
    terra::distance(as.matrix(before[c(lon, lat)]), as.matrix(after[c(lon, lat)]),
                    lonlat = TRUE, pairwise = TRUE)
}

# many locations, half urban, inside the fixture's area
many_points <- function(n = 400) {
    set.seed(42)
    data.frame(id = seq_len(n),
               lon = stats::runif(n, 30.1, 31.1), lat = stats::runif(n, -0.9, 0.1),
               area = rep(c("urban", "rural"), length.out = n))
}

test_that("each location moves by no more than its limit", {
    x <- many_points()
    out <- quiet(displace_coord(x, lat = lat, lon = lon, type = area,
                                share_far = 0, seed = 1))
    moved <- moved_m(x, out)
    urban <- x$area == "urban"
    # the metre-per-degree approximation is good to a fraction of a percent
    expect_true(all(moved[urban] <= 2000 * 1.005))
    expect_true(all(moved[!urban] <= 5000 * 1.005))
    expect_gt(max(moved[!urban]), 2000)
    expect_true(all(moved > 0))
})

test_that("a share of rural locations moves up to the far limit", {
    x <- many_points()
    out <- quiet(displace_coord(x, lat = lat, lon = lon, type = area,
                                share_far = 0.1, seed = 2))
    moved <- moved_m(x, out)
    rural <- x$area == "rural"
    expect_true(all(moved[rural] <= 10000 * 1.005))
    expect_true(any(moved[rural] > 5000 * 1.005))
    expect_equal(c4e_meta(out)$survey$displaced$n_far, 20)
})

test_that("without a type every location is displaced as rural, and says so", {
    x <- many_points(50)
    expect_message(out <- displace_coord(x, lat = lat, lon = lon, seed = 3),
                   "rural")
    expect_true(all(moved_m(x, out) <= 5000 * 1.005))
    expect_false(c4e_meta(out)$survey$displaced$typed)
})

test_that("households at the same location move together", {
    survey <- synthetic_survey()
    coord <- prepare_coord(survey, lat, lon, id = hhid, interview = interview)
    out <- quiet(displace_coord(coord, seed = 4))
    before <- vctrs::vec_group_id(tibble::as_tibble(coord)[c("lon", "lat")])
    after <- vctrs::vec_group_id(tibble::as_tibble(out)[c("lon", "lat")])
    expect_equal(as.integer(after), as.integer(before))
    expect_equal(nrow(out), nrow(coord))
})

test_that("the same seed gives the same displacement and leaves the random state", {
    x <- many_points(30)
    set.seed(99)
    state <- .Random.seed
    a <- quiet(displace_coord(x, lat = lat, lon = lon, seed = 5))
    expect_identical(.Random.seed, state)
    b <- quiet(displace_coord(x, lat = lat, lon = lon, seed = 5))
    c <- quiet(displace_coord(x, lat = lat, lon = lon, seed = 6))
    expect_equal(a$lon, b$lon)
    expect_false(isTRUE(all.equal(a$lon, c$lon)))
})

test_that("locations stay inside their administrative division", {
    adm <- synthetic_adm_div()
    x <- many_points(200)
    out <- quiet(displace_coord(x, lat = lat, lon = lon, rural = 20000,
                                boundaries = adm, seed = 7))
    before <- division_of(x$lon, x$lat, adm)
    after <- division_of(out$lon, out$lat, adm)
    inside <- !is.na(before)
    expect_equal(after[inside], before[inside])
    expect_true(c4e_meta(out)$survey$displaced$within_boundaries)
})

test_that("coordinate identifiers are rebuilt from the displaced locations", {
    coord <- prepare_coord(synthetic_survey(), lat, lon, id = hhid, interview = interview)
    out <- quiet(displace_coord(coord, seed = 8))
    expect_false(any(out$ID %in% coord$ID))
    expect_equal(out$ID, coordinate_id(out$lon, out$lat, 5))
})

test_that("the displacement is recorded, without the seed, and travels on", {
    coord <- prepare_coord(synthetic_survey(), lat, lon, id = hhid, interview = interview)
    out <- quiet(displace_coord(coord, seed = 12345))
    record <- c4e_meta(out)$survey$displaced
    expect_equal(record[c("rule", "rural", "rural_far")],
                 list(rule = "DHS", rural = 5000, rural_far = 10000))
    calls <- c4e_history(out)$call
    expect_match(calls[length(calls)], "^displace_coord\\(")
    expect_false(any(grepl("12345", calls)))

    expect_match(c4e_labels(out)[["lon"]], "displaced up to 5/10 km")
    expect_match(describe_meta(c4e_meta(out)), "displaced coordinates")

    # the record reaches the indicators computed at the displaced locations
    heat <- quiet(weather_extremes(out, system.file("extdata", "tmax_daily.tif",
                                                    package = "c4e"),
                                   preset = "heat"))
    expect_equal(c4e_meta(heat)$survey$displaced$rule, "DHS")
    path <- withr::local_tempfile(fileext = ".dta")
    write_stata(heat, path, codebook = TRUE)
    codebook <- readLines(sub("\\.dta$", "_codebook.md", path))
    expect_true(any(grepl("Coordinates: displaced up to 5/10 km", codebook)))
})

test_that("bad input is refused clearly", {
    x <- many_points(10)
    x$area[1] <- "suburb"
    expect_error(displace_coord(x, lat = lat, lon = lon, type = area), "urban or rural")
    expect_error(displace_coord(x, lat = lat, lon = lon, rural = -1), "rural")
    expect_error(displace_coord(data.frame(a = 1)), "lat")
})
