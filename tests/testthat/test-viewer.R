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

# One district, two years, both bases, exercising a fin_unit/campus
# split (China Spring rows 1-2 share fund/function/object but differ by
# fin_unit -- the aggregation must sum these into one row).
viewer_fake_peims <- function(year, basis, type) {
  if (type == "charter") {
    if (year != 2024L) {
      # Mirrors txs_get_peims_finance()'s real behavior for a combo TEA
      # has not published: it errors, it does not return empty.
      stop(sprintf("No PEIMS %s %s file is published for year=%d.",
                   type, basis, year), call. = FALSE)
    }
    return(tibble::tibble(
      district = "240001", district_name = "Test Charter",
      fin_unit = "000", campus_name = "NO COST CENTER",
      year = year, school_year = year_label(year),
      basis = basis, type = type,
      fund_code = "420", fund_label = "FOOD SVC",
      function_code = "35", function_label = "FOOD SERVICES",
      object_code = "6341", object_label = "FOOD",
      program_intent_code = "00", program_intent_label = "NO PROGRAM",
      amount = 45, fiscal_year = year, updated = as.Date("2024-01-01")
    ))
  }
  tibble::tibble(
    district = "161920", district_name = "China Spring ISD",
    fin_unit = c("000", "001"), campus_name = c("NO COST CENTER", "ELEM"),
    year = year, school_year = year_label(year),
    basis = basis, type = type,
    fund_code = "199", fund_label = "GENERAL FUND",
    function_code = "11", function_label = "INSTRUCTION",
    object_code = "6119", object_label = "PAYROLL",
    program_intent_code = "00", program_intent_label = "NO PROGRAM",
    amount = c(300, 200), fiscal_year = year, updated = as.Date("2024-01-01")
  )
}

test_that("txs_viewer_prepare_finance aggregates away campus detail", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_get_peims_finance = function(year, basis, type, ...) {
      viewer_fake_peims(year, basis, type)
    }
  )

  res <- txs_viewer_prepare_finance(years = c(2023L, 2024L),
                                    basis = c("actual", "budget"),
                                    verbose = FALSE)
  expect_true(file.exists(res$path))
  summary <- readRDS(res$path)

  # fin_unit/campus_name are gone; the 000/001 split for China Spring
  # collapsed into one summed row (300 + 200 = 500) per year/basis.
  expect_false(any(c("fin_unit", "campus_name") %in% names(summary)))
  cs <- summary[summary$district == "161920" & summary$year == 2024 &
                  summary$basis == "actual", ]
  expect_equal(nrow(cs), 1L)
  expect_equal(cs$amount, 500)

  # The unpublished 2023 charter combo was skipped, not fatal.
  expect_false(any(summary$type == "charter" & summary$year == 2023))
  expect_length(res$combos_failed, 2L)  # 2023 charter x {actual, budget}
  expect_true(any(grepl("2022-23 charter (actual|budget)", res$combos_failed)))

  # Sidecar visible to the cache tooling.
  inv <- txs_cache_list()
  expect_true(any(inv$source == "viewer" & inv$data_type == "peims_summary"))
})

test_that("txs_viewer_prepare_finance defaults years via txs_list_years", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_years = function(source, ...) {
      tibble::tibble(source = "peims", year = 2018:2024,
                     school_year = vapply(2018:2024, txschools:::year_label, ""))
    },
    txs_get_peims_finance = function(year, basis, type, ...) {
      viewer_fake_peims(year, basis, type)
    }
  )
  res <- txs_viewer_prepare_finance(basis = "actual", verbose = FALSE)
  expect_setequal(res$years, 2020:2024)  # tail(..., 5) of 2018:2024
})

test_that("fin_axes_presets() offers only axes valid for txs_peims_flow()", {
  app_dir <- system.file("viewer", package = "txschools")
  skip_if(app_dir == "", "inst/viewer not installed")
  e <- new.env()
  sys.source(file.path(app_dir, "helpers.R"), envir = e)

  presets <- e$fin_axes_presets()
  expect_s3_class(presets, "tbl_df")
  expect_true(all(c("key", "label", "axes") %in% names(presets)))

  # A minimal fixture with one row per object class so every preset's
  # required columns are satisfiable.
  x <- tibble::tibble(
    fund_code = "199", fund_label = "GENERAL FUND",
    function_code = c("00", "11"),
    function_label = c("NO FUNCTION", "INSTRUCTION"),
    object_code = c("5711", "6119"),
    object_label = c("OTHER LOCAL", "PAYROLL"),
    program_intent_code = "00", program_intent_label = "NO PROGRAM",
    amount = c(600, 500)
  )
  for (i in seq_len(nrow(presets))) {
    ax <- presets$axes[[i]]
    expect_no_error(txs_peims_flow(x, axes = ax))
    expect_identical(e$fin_axes_for(presets$key[i]), ax)
  }
})
