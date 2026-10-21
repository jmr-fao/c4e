# Identifiers are always character, because they name a unit rather than
# measure one.

# --- identifier type -------------------------------------------------------

test_that("every ID the package generates is character", {
    coords <- prepare_coord(data.frame(lat = c(1, 2), lon = c(10, 20)), lat, lon)
    expect_type(coords$ID, "character")
})

test_that("ID_adm_div is character wherever it is produced", {
    r <- terra::rast(xmin = 0, xmax = 10, ymin = 0, ymax = 10,
                     res = 1, crs = "epsg:4326")
    terra::values(r) <- seq_len(terra::ncell(r))
    p <- terra::vect(terra::ext(2, 5, 2, 5), crs = "epsg:4326")

    expect_type(extract_cell_by_poly(r, p)$ID_adm_div, "character")
})

