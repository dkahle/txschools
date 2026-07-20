viewer_fake_rates <- function() {
  tibble::tibble(
    year = rep(c(2023L, 2024L), each = 2),
    school_year = rep(c("2022-23", "2023-24"), each = 2),
    district = rep(c("161920", "057905"), 2),
    district_name = rep(c("China Spring ISD", "Dallas ISD"), 2),
    mo_rate = c(0.85, 0.87, 0.6774, 0.7052),
    is_rate = c(0.32, 0.24, 0.34398, 0.242035),
    total_rate = c(1.17, 1.11, 1.02138, 0.947235),
    mcr = c(NA, NA, 0.6692, 0.6692),
    rate_source = "comptroller"
  )
}

viewer_fake_xwalk <- function() {
  tibble::tibble(
    geoid = c("4813960", "4816860"),
    district = c("161920", "057905"),
    lea_name = c("CHINA SPRING ISD", "DALLAS ISD")
  )
}

viewer_fake_boundaries <- function() {
  sf::st_sf(
    geoid = c("4813960", "4816860"),
    name = c("China Spring ISD", "Dallas ISD"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0)))),
      sf::st_polygon(list(cbind(c(2, 3, 3, 2, 2), c(0, 0, 1, 1, 0)))),
      crs = 4326
    )
  )
}

test_that("txs_viewer_prepare bakes the three artifacts", {
  skip_if_not_installed("sf")
  skip_if_not_installed("jsonlite")
  local_cache()
  testthat::local_mocked_bindings(
    txs_get_tax_rates = function(...) viewer_fake_rates(),
    txs_crosswalk = function(...) viewer_fake_xwalk(),
    txs_boundaries = function(...) viewer_fake_boundaries()
  )

  res <- txs_viewer_prepare(verbose = FALSE)
  expect_true(all(file.exists(res$paths)))

  districts <- readRDS(res$paths[["districts"]])
  expect_s3_class(districts, "sf")
  value_cols <- setdiff(names(districts),
                        c("geoid", "district_name", "geometry"))
  expect_true(all(grepl(
    "^(total_rate|mo_rate|is_rate|mcr|golden_rate|copper_rate|golden_pennies|copper_pennies)__\\d{4}_\\d{2}$",
    value_cols
  )))
  expect_equal(
    districts$total_rate__2023_24[districts$geoid == "4813960"], 1.02138
  )
  # Penny fields derived: 2023-24 China Spring golden = mo - mcr capped.
  expect_equal(
    districts$golden_pennies__2023_24[districts$geoid == "4813960"],
    round(min(0.6774 - 0.6692, 0.08) * 100)
  )

  finance <- readRDS(res$paths[["finance"]])
  expect_true(all(c("geoid", "year", "school_year", "district",
                    "mo_rate", "golden_rate", "total_rate") %in%
                    names(finance)))

  meta <- jsonlite::read_json(res$paths[["meta"]], simplifyVector = TRUE)
  expect_equal(meta$n_districts_total, 2L)
  expect_equal(meta$n_districts_with_data, 2L)
  expect_setequal(meta$school_years, c("2022-23", "2023-24"))

  # Artifacts are visible to the cache tooling via sidecars.
  inv <- txs_cache_list()
  expect_true("viewer" %in% inv$source)
})

test_that("txs_viewer errors helpfully without prepared data", {
  skip_if_not_installed("shiny")
  local_cache()
  expect_error(txs_viewer(), "txs_viewer_prepare")
})

test_that("txs_viewer names every missing suggest at once", {
  real_rn <- base::requireNamespace
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) {
      if (package %in% c("mapgl", "shinyWidgets")) FALSE
      else real_rn(package, ...)
    },
    .package = "base"
  )
  expect_error(txs_viewer(), "mapgl.*shinyWidgets")
})

test_that("the shipped app sources cleanly", {
  # A parse check that the inst/viewer files are valid R.
  app_dir <- system.file("viewer", package = "txschools")
  skip_if(app_dir == "", "inst/viewer not installed")
  expect_no_error(parse(file.path(app_dir, "app.R")))
  expect_no_error(parse(file.path(app_dir, "helpers.R")))
})
