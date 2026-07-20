test_that("simplify_boundaries falls back without rmapshaper", {
  skip_if_not_installed("sf")
  sq <- sf::st_sf(
    geoid = "4819910",
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0)))),
      crs = 4326
    )
  )
  real_rn <- base::requireNamespace
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) {
      if (package == "rmapshaper") FALSE else real_rn(package, ...)
    },
    .package = "base"
  )
  out <- suppressMessages(simplify_boundaries(sq, verbose = FALSE))
  expect_s3_class(out, "sf")
  expect_equal(as.character(sf::st_crs(out)$epsg), "4326")
})

test_that("txs_boundaries caches the simplified sf", {
  skip_if_not_installed("sf")
  local_cache()
  sq <- sf::st_sf(
    GEOID = c("4819910", "4816860"),
    NAME = c("China Spring ISD", "Dallas ISD"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0)))),
      sf::st_polygon(list(cbind(c(2, 3, 3, 2, 2), c(0, 0, 1, 1, 0)))),
      crs = 4326
    )
  )
  testthat::local_mocked_bindings(
    school_districts = function(...) sq, .package = "tigris"
  )

  x <- txs_boundaries(verbose = FALSE)
  expect_s3_class(x, "sf")
  expect_true(all(c("geoid", "name") %in% names(x)))
  expect_equal(attr(x, "txschools")$source, "boundaries")

  testthat::local_mocked_bindings(
    school_districts = function(...) stop("no network"), .package = "tigris"
  )
  x2 <- txs_boundaries(verbose = FALSE)
  expect_equal(x2$geoid, x$geoid)
})
