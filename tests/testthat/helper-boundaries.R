# Builders of miniature boundary directory trees, shared by the boundary
# reader tests (moved here from test-read-gaul.R and test-read-boundaries.R).

# GAUL files sit one level deeper than geoBoundaries and use different field
# names:  root/<ISO>/<folder matching ADM{lvl}>/<file matching ADM[012].geojson>
# with iso3_code, gaul1_name and gaul2_name attributes.
make_gaul_tree <- function(root, iso = "KEN", lvl = 2, n = 3) {
    dir <- file.path(root, iso, paste0(iso, "_ADM", lvl))
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)

    v <- do.call(rbind, lapply(seq_len(n), \(i) {
        terra::vect(terra::ext((i - 1) * 2, (i - 1) * 2 + 2, 0, 2),
                    crs = "epsg:4326")
    }))
    v$iso3_code <- iso
    v$gaul1_name <- paste0("Region_", seq_len(n))
    if (lvl == 2) v$gaul2_name <- paste0("District_", seq_len(n))

    terra::writeVector(v, file.path(dir, paste0(iso, "_ADM", lvl, ".geojson")),
                       filetype = "GeoJSON", overwrite = TRUE)
    root
}

# Build a miniature geoBoundaries-style directory tree:
#   root/<ISO>/<subfolder>/<ISO>_ADM1.geojson
# with the shapeName / shapeGroup / shapeType fields the reader renames.
make_boundary_tree <- function(root, iso = "KEN", n_adm1 = 2, n_adm2 = 4) {
    dir <- file.path(root, iso, "geoBoundaries")
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)

    square <- function(x0, y0, w = 1) {
        terra::vect(terra::ext(x0, x0 + w, y0, y0 + w), crs = "epsg:4326")
    }

    adm1 <- do.call(rbind, lapply(seq_len(n_adm1), \(i) square((i - 1) * 2, 0, 2)))
    adm1$shapeName  <- paste0("Region_", seq_len(n_adm1))
    adm1$shapeGroup <- iso
    adm1$shapeType  <- "ADM1"
    terra::writeVector(adm1, file.path(dir, paste0(iso, "_ADM1.geojson")),
                       filetype = "GeoJSON", overwrite = TRUE)

    # two ADM2 units nested inside each ADM1 square
    adm2 <- do.call(rbind, lapply(seq_len(n_adm2), \(i) {
        parent <- (i - 1) %/% 2
        offset <- ((i - 1) %% 2)
        square(parent * 2 + offset, 0, 1)
    }))
    adm2$shapeName  <- paste0("District_", seq_len(n_adm2))
    adm2$shapeGroup <- iso
    adm2$shapeType  <- "ADM2"
    terra::writeVector(adm2, file.path(dir, paste0(iso, "_ADM2.geojson")),
                       filetype = "GeoJSON", overwrite = TRUE)

    root
}
