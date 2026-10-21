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

# a lake and a population raster over the fixture's area
lake_at <- function(lon = 30.6, lat = -0.4, r = 15000) {
    terra::buffer(terra::vect(cbind(lon, lat), crs = "EPSG:4326"), r, quadsegs = 60)
}
people_per_km2 <- function(density = 100) {
    pop <- terra::rast(xmin = 29.8, xmax = 31.4, ymin = -1.2, ymax = 0.4,
                       resolution = 0.005, crs = "EPSG:4326")
    terra::values(pop) <- density * terra::values(terra::cellSize(pop, unit = "km"))[, 1]
    pop
}

test_that("locations never land in a water body", {
    x <- many_points(300)
    lake <- lake_at()
    x <- x[!in_water(x$lon, x$lat, water_bodies(lake, 0)), ]
    out <- quiet(displace_coord(x, lat = lat, lon = lon, rural = 20000,
                                water = lake, seed = 9))
    expect_false(any(in_water(out$lon, out$lat, water_bodies(lake, 0))))
    expect_true(c4e_meta(out)$survey$displaced$off_water)

    # a true location in the water is moved out of it, with a warning
    wet <- data.frame(lon = 30.6, lat = -0.4)
    expect_warning(out <- quiet(displace_coord(wet, lat = lat, lon = lon, rural = 20000,
                                               water = lake, seed = 1)),
                   "in `water`")
    expect_false(in_water(out$lon, out$lat, water_bodies(lake, 0)))
})

test_that("min_water_area keeps only the large water bodies", {
    ponds <- rbind(lake_at(r = 15000), lake_at(30.2, 0, r = 300))
    expect_equal(nrow(water_bodies(ponds, 0)), 2)
    expect_equal(nrow(water_bodies(ponds, 1)), 1)
    expect_error(displace_coord(many_points(5), lat = lat, lon = lon,
                                water = terra::vect(cbind(30.5, -0.5), crs = "EPSG:4326")),
                 "polygons")
})

test_that("the population radius holds min_people", {
    pop <- people_per_km2(100)
    # 100 people per km2: 11,310 people live within 6 km
    k <- pi * 6^2 * 100
    r <- people_radius(30.6, -0.4, 5000, NULL, NULL, pop, k, 1, 3)
    expect_equal(r, 6000, tolerance = 0.01)
    # dense enough already: the DHS limit is the floor, or min_scale below it
    expect_equal(people_radius(30.6, -0.4, 5000, NULL, NULL, pop, 100, 1, 3), 5000)
    expect_equal(people_radius(30.6, -0.4, 5000, NULL, NULL, pop, 100, 0.5, 3), 2500)
    # water holds nobody, so a lake next to the location widens the radius
    lake <- water_bodies(lake_at(30.6, -0.45, r = 3000), 0)
    expect_gt(people_radius(30.6, -0.4, 5000, NULL, lake, pop, k, 1, 3), 6000)
})

test_that("population widens sparse locations and records it", {
    x <- many_points(40)
    pop <- people_per_km2(100)
    # 10,936 people live within 5.9 km, below three times the 2 km urban limit
    k <- round(pi * 5.9^2 * 100)
    out <- quiet(displace_coord(x, lat = lat, lon = lon, type = area, share_far = 0,
                                population = pop, min_people = k, seed = 10))
    moved <- moved_m(x, out)
    rural <- x$area == "rural"
    expect_true(all(moved[rural] <= 5900 * 1.02))
    expect_true(any(moved[rural] > 5000 * 1.005))
    expect_true(all(moved[!rural] <= 5900 * 1.02))
    record <- c4e_meta(out)$survey$displaced$population
    expect_equal(record$min_people, k)
    expect_equal(record$n_widened, 40)
    expect_match(c4e_labels(out)[["lon"]], "radius set for 10,936 people")

    # too few people even at max_scale: a warning, and the cap holds
    expect_warning(quiet(displace_coord(x, lat = lat, lon = lon, type = area,
                                        population = pop, min_people = 1e7, seed = 11)),
                   "max_scale")
})

test_that("population options are checked", {
    x <- many_points(5)
    pop <- people_per_km2()
    expect_error(displace_coord(x, lat = lat, lon = lon, population = pop), "min_people")
    expect_error(displace_coord(x, lat = lat, lon = lon, population = c(pop, pop),
                                min_people = 10), "one raster layer")
    expect_error(displace_coord(x, lat = lat, lon = lon, population = pop,
                                min_people = 10, min_scale = 2, max_scale = 1), "min_scale")
    far_away <- terra::rast(xmin = 0, xmax = 1, ymin = 0, ymax = 1, resolution = 0.1,
                            crs = "EPSG:4326", vals = 1)
    expect_error(quiet(displace_coord(x, lat = lat, lon = lon, population = far_away,
                                      min_people = 10)), "does not cover")
})
