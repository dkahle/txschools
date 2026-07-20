#' Texas school district boundaries (via tigris)
#'
#' Downloads and simplifies the Census cartographic school-district
#' boundaries for Texas, returned as an `sf` in WGS84 (EPSG:4326) --
#' the projection web maps expect. The `geoid` column is the 7-digit
#' NCES LEAID; join TEA-keyed tables through [txs_crosswalk()].
#'
#' Requires the suggested packages sf and tigris (and uses rmapshaper
#' for higher-quality simplification when installed, falling back to
#' `sf::st_simplify()`).
#'
#' @param year Census TIGER vintage; vintages lag the calendar year, so
#'   a recent-but-settled year is the safe default.
#' @param keep Fraction of vertices to keep when simplifying (0-1).
#' @param cb Use cartographic-boundary (generalized) geometry.
#' @inheritParams txs_get_peims_finance
#' @return An `sf` data frame with columns `geoid`, `name`, and
#'   `geometry`, plus a `txschools` attribute.
#' @examples
#' \dontrun{
#' txs_boundaries()
#' }
#' @export
txs_boundaries <- function(year = 2023,
                           keep = 0.15,
                           cb = TRUE,
                           cache = TRUE,
                           refresh = FALSE,
                           verbose = TRUE) {
  for (pkg in c("sf", "tigris")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Package `", pkg, "` is required for district boundaries. ",
           'Install it with install.packages("', pkg, '").', call. = FALSE)
    }
  }
  cache <- isTRUE(cache)
  filename <- sprintf(
    "school_districts_%s_keep%02d.rds", if (cb) "cb" else "tl",
    round(keep * 100)
  )
  dest <- cache_path("boundaries", year, file = filename)
  if (!cache) dest <- temp_download_path(filename)

  if (cache && !refresh && file.exists(dest)) {
    if (verbose) cli::cli_alert_info("Using cached boundaries: {dest}")
    out <- readRDS(dest)
    meta <- read_sidecar(dest)
  } else {
    if (verbose) {
      cli::cli_alert_info(
        "Downloading TX school district boundaries (tigris, {year})"
      )
    }
    bd <- tigris::school_districts(state = "TX", year = year, cb = cb,
                                   progress_bar = FALSE)
    keep_cols <- intersect(c("GEOID", "NAME"), names(bd))
    bd <- bd[, keep_cols]
    names(bd)[names(bd) == "GEOID"] <- "geoid"
    names(bd)[names(bd) == "NAME"] <- "name"
    bd <- sf::st_transform(bd, 4326)
    bd <- simplify_boundaries(bd, keep = keep, verbose = verbose)
    out <- sf::st_make_valid(bd)

    meta <- list(
      source = "boundaries", year = as.integer(year),
      school_year = NA_character_, level = "district",
      data_type = if (cb) "cartographic" else "tiger",
      dataset = NA_character_, file_format = "rds",
      source_url = "https://www.census.gov/geographies/mapping-files.html",
      retrieved_at = iso8601_now(), size_bytes = NA_real_,
      sha256 = NA_character_
    )
    if (cache) {
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      saveRDS(out, dest)
      meta$sha256 <- sha256_file(dest)
      meta$size_bytes <- file.size(dest)
      write_sidecar(dest, meta)
    }
  }

  attr(out, "txschools") <- meta
  out
}

# Simplify polygons, preserving shared borders where rmapshaper is
# available; otherwise sf::st_simplify in a projected CRS (NAD83 Texas
# Centric Albers, EPSG:3083; dTolerance in meters).
simplify_boundaries <- function(x, keep = 0.15, verbose = TRUE) {
  if (requireNamespace("rmapshaper", quietly = TRUE)) {
    return(rmapshaper::ms_simplify(x, keep = keep, keep_shapes = TRUE))
  }
  if (verbose) {
    cli::cli_alert_info(
      "rmapshaper not installed; using sf::st_simplify fallback."
    )
  }
  proj <- sf::st_transform(x, 3083)
  simp <- sf::st_simplify(proj, dTolerance = 250, preserveTopology = TRUE)
  sf::st_transform(simp, 4326)
}
