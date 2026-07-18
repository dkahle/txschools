# A minimal PEIMS result carrying the attribute txs_write_peims_db needs.
peims_db_object <- function(year = 2024L, basis = "actual",
                            type = "district") {
  x <- tibble::tibble(
    district = c("001902", "001903"),
    fund_code = "199", function_code = "11", object_code = "6119",
    amount = c(1000000, 875000),
    year = year, basis = basis, type = type
  )
  attr(x, "txschools") <- list(
    source = "peims", year = year, school_year = year_label(year),
    level = type, data_type = basis, basis = basis, type = type,
    source_url = "https://example.org/actget2024.zip",
    retrieved_at = iso8601_now(), sha256 = "abc123"
  )
  x
}

test_that("txs_write_peims_db writes the data and meta tables", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")

  dbf <- withr::local_tempfile(fileext = ".duckdb")
  x <- peims_db_object()
  expect_identical(txs_write_peims_db(x, dbf), x)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = dbf)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  expect_true(DBI::dbExistsTable(con, "peims_finance_actual_district_2024"))
  got <- DBI::dbReadTable(con, "peims_finance_actual_district_2024")
  expect_equal(nrow(got), 2L)
  meta <- DBI::dbReadTable(con, "_peims_meta")
  expect_equal(meta$table, "peims_finance_actual_district_2024")
  expect_equal(meta$year, 2024L)
})

test_that("txs_write_peims_db appends meta across multiple writes", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")

  dbf <- withr::local_tempfile(fileext = ".duckdb")
  txs_write_peims_db(peims_db_object(2024L), dbf)
  txs_write_peims_db(peims_db_object(2023L), dbf)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = dbf)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  expect_true(DBI::dbExistsTable(con, "peims_finance_actual_district_2023"))
  expect_true(DBI::dbExistsTable(con, "peims_finance_actual_district_2024"))
  expect_equal(nrow(DBI::dbReadTable(con, "_peims_meta")), 2L)
})

test_that("txs_write_peims_db refuses to clobber without overwrite", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")

  dbf <- withr::local_tempfile(fileext = ".duckdb")
  txs_write_peims_db(peims_db_object(), dbf)
  expect_error(txs_write_peims_db(peims_db_object(), dbf),
               "already exists")
  expect_silent(txs_write_peims_db(peims_db_object(), dbf,
                                   overwrite = TRUE))
})

test_that("txs_write_peims_db validates its input", {
  skip_if_not_installed("DBI")
  expect_error(txs_write_peims_db(tibble::tibble(a = 1), "x.duckdb"),
               "txs_get_peims_finance")
})

test_that("the getter's db argument writes through", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  local_cache()

  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )

  dbf <- withr::local_tempfile(fileext = ".duckdb")
  txs_get_peims_finance(2024, "actual", "district",
                        db = dbf, verbose = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = dbf)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  expect_true(DBI::dbExistsTable(con, "peims_finance_actual_district_2024"))
})
