# A miniature ASIS phenology tree, the layout read_season() expects:
#   root/FAO_ASIS/PHE/global/DATA_ASIS_MAPSET_PHE_ASIS.PHE.GS<n>.<STAGE>.<LC>.tif
#
# The rasters are the same 6 x 6 grid as the other fixtures, so they line up
# with synthetic_adm_div() and survey.csv. Values are dekads, signed and
# linear from 1 January as ASIS publishes them, with the real flag values in
# the cells that carry no season:
#
#   251 no season   252 error   253 insufficient data
#   254 outside the land-cover mask   255 water   -9999 no data
#
# The cropland layer is deliberately holed: the lower half of the grid is 254
# (no cropland), and the pasture layer covers most of that hole. That is the
# Sahel pattern the cropland-with-pasture fallback exists for, and without it
# the fallback cannot be tested.
season_grid <- function() {
    terra::rast(nrows = 6, ncols = 6, xmin = 30, xmax = 31.2,
                ymin = -1, ymax = 0.2, crs = "EPSG:4326")
}

# `hole` marks the cells that carry no season in this land cover.
asis_layer <- function(value, hole, flag = 254) {
    r <- season_grid()
    v <- rep(value, terra::ncell(r))
    v[hole] <- flag
    terra::values(r) <- v
    r
}

make_asis_tree <- function(root) {
    dir <- file.path(root, "FAO_ASIS", "PHE", "global")
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)

    cells <- seq_len(36)
    lower <- cells > 18          # the bottom three rows
    upper <- !lower

    # Season 1 runs within the year; season 2 starts late and crosses into the
    # next one, which is why ASIS dekads go past 36.
    spec <- list(
        list(gs = 1, stage = "SOS", lc = "LC-C", value = 4,  hole = lower),
        list(gs = 1, stage = "MOS", lc = "LC-C", value = 10, hole = lower),
        list(gs = 1, stage = "EOS", lc = "LC-C", value = 18, hole = lower),
        list(gs = 2, stage = "SOS", lc = "LC-C", value = 28, hole = lower),
        list(gs = 2, stage = "MOS", lc = "LC-C", value = 34, hole = lower),
        list(gs = 2, stage = "EOS", lc = "LC-C", value = 40, hole = lower),
        # pasture covers the cropland hole, except the last three cells, which
        # stay empty under both covers so that a division can have no season
        # at all.
        list(gs = 1, stage = "SOS", lc = "LC-G", value = 6,  hole = cells > 33),
        list(gs = 1, stage = "MOS", lc = "LC-G", value = 12, hole = cells > 33),
        list(gs = 1, stage = "EOS", lc = "LC-G", value = 20, hole = cells > 33),
        list(gs = 2, stage = "SOS", lc = "LC-G", value = 30, hole = cells > 33),
        list(gs = 2, stage = "MOS", lc = "LC-G", value = 35, hole = cells > 33),
        list(gs = 2, stage = "EOS", lc = "LC-G", value = 42, hole = cells > 33)
    )
    for (s in spec) {
        f <- file.path(dir, sprintf(
            "DATA_ASIS_MAPSET_PHE_ASIS.PHE.GS%d.%s.%s.tif", s$gs, s$stage, s$lc))
        terra::writeRaster(asis_layer(s$value, s$hole), f, overwrite = TRUE)
    }
    root
}

# One more flag per code, so the masking is tested against each of them rather
# than only against 254.
make_asis_flags <- function(root, flags = c(251, 252, 253, 255, -9999)) {
    dir <- file.path(root, "FAO_ASIS", "PHE", "global")
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    r <- season_grid()
    v <- rep(8, terra::ncell(r))
    v[seq_along(flags)] <- flags
    terra::values(r) <- v
    for (stage in c("SOS", "MOS", "EOS")) {
        terra::writeRaster(r, file.path(dir, sprintf(
            "DATA_ASIS_MAPSET_PHE_ASIS.PHE.GS1.%s.LC-C.tif", stage)),
            overwrite = TRUE)
    }
    root
}
