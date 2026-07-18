# Offline end-to-end tests for txs_get_peims_finance. Discovery and
# downloads are stubbed to fixtures (see helper-peims.R); the
# code-table download happens inside
# peims_tidy() -> peims_code_tables(); namespace-level mocking via
# testthat::local_mocked_bindings() reaches those nested calls, which
# mockery::stub() cannot.

test_that("district actuals parse, type, pad, and label", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )

  x <- txs_get_peims_finance(2024, "actual", "district", verbose = FALSE)
  expect_s3_class(x, "tbl_df")
  expect_equal(nrow(x), 6L)
  expect_equal(
    names(x)[1:8],
    c("district", "district_name", "fin_unit", "campus_name",
      "year", "school_year", "basis", "type")
  )
  expect_true(all(nchar(x$district) == 6L))
  expect_true(all(nchar(x$fund_code) == 3L))
  expect_true(all(nchar(x$object_code) == 4L))
  expect_type(x$amount, "double")
  expect_equal(x$amount[1], -4381123)
  expect_s3_class(x$updated, "Date")
  expect_equal(unique(x$basis), "actual")
  expect_equal(unique(x$type), "district")
  expect_equal(x$district_name[x$district == "001902"][1], "CAYUGA ISD")
  expect_equal(x$campus_name[x$district == "001902" & x$fin_unit == "001"][1],
               "CAYUGA H S")
  expect_equal(x$fund_label[x$fund_code == "199"][1], "GENERAL FUND")
  expect_equal(x$function_label[x$function_code == "11"][1], "INSTRUCTION")
  expect_false(any(is.na(x$object_label)))

  meta <- attr(x, "txschools")
  expect_equal(meta$source, "peims")
  expect_equal(meta$level, "district")
  expect_equal(meta$data_type, "actual")
  expect_equal(meta$basis, "actual")
  expect_null(meta$masking_values)
  expect_true(file.exists(meta$cache_path))
})

test_that("charter files normalize the nonprofit chart of accounts", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )

  x <- txs_get_peims_finance(2024, "budget", "charter", verbose = FALSE)
  expect_equal(nrow(x), 3L)
  expect_true(all(c("fund_code", "function_code", "object_code",
                    "program_intent_code") %in% names(x)))
  # Fund 420 is absent from the charter chart of accounts; its label
  # must come from the district fund table.
  expect_equal(x$fund_label[x$fund_code == "420"][1],
               "FOUNDATION SCHOOL PROGRAM")
  expect_equal(x$fund_label[x$fund_code == "240"][1],
               "NATIONAL SCHOOL BREAKFAST AND LUNCH PROGRAM")
  expect_equal(x$amount[3], -750)
  expect_equal(x$district_name[1], "PINEYWOODS COMMUNITY ACADEMY")
})

test_that("labels degrade gracefully when code tables are unavailable", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) NA_character_
  )

  expect_warning(
    x <- txs_get_peims_finance(2024, "actual", "district", verbose = FALSE),
    "code tables"
  )
  expect_false("fund_label" %in% names(x))
  expect_true("fund_code" %in% names(x))
})

test_that("labels = FALSE skips code tables entirely", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) stop("should not be called")
  )

  x <- txs_get_peims_finance(2024, "actual", "district",
                             labels = FALSE, verbose = FALSE)
  expect_false("fund_label" %in% names(x))
})

test_that("output = 'raw' returns all-character columns as published", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )

  x <- txs_get_peims_finance(2024, "actual", "district",
                             output = "raw", labels = FALSE, verbose = FALSE)
  expect_true(all(vapply(x, is.character, logical(1))))
  expect_true("ACTAMT" %in% names(x))
  expect_equal(x$DISTRICT[1], "001902")
})

test_that("keep_raw attaches the untouched parse", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )
  x <- txs_get_peims_finance(2024, "actual", "district",
                             keep_raw = TRUE, verbose = FALSE)
  raw <- attr(x, "raw")
  expect_s3_class(raw, "tbl_df")
  expect_true("ACTAMT" %in% names(raw))
})

test_that("second call reads from cache and is inventoried", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )
  x1 <- txs_get_peims_finance(2024, "actual", "district", verbose = FALSE)
  expect_false(attr(x1, "txschools")$used_cache)

  testthat::local_mocked_bindings(
    http_download = function(...) stop("network should not be touched")
  )
  x2 <- txs_get_peims_finance(2024, "actual", "district", verbose = FALSE)
  expect_true(attr(x2, "txschools")$used_cache)

  inv <- txs_cache_list()
  peims <- inv[inv$source == "peims", ]
  expect_setequal(peims$level, c("district", "codes"))
  expect_true(all(peims$year == 2024))
})

test_that("unavailable basis/type errors with the available combos", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads()
  )
  expect_error(
    txs_get_peims_finance(2024, "budget", "district", verbose = FALSE),
    "No PEIMS district budget file.*Available:.*district actual"
  )
})

test_that("HTML error pages are detected and removed", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads()
  )
  mockery::stub(
    txs_get_peims_finance, "http_download",
    function(url, dest, ...) {
      writeLines("<!DOCTYPE html><html>moved</html>", dest)
      list(path = dest, sha256 = "x", size_bytes = file.size(dest),
           content_type = "text/html", retrieved_at = iso8601_now(),
           source_url = url)
    }
  )
  expect_error(
    txs_get_peims_finance(2024, "actual", "district", verbose = FALSE),
    "HTML page instead of a data file"
  )
})

test_that("txs_cite renders a PEIMS citation", {
  local_cache()
  testthat::local_mocked_bindings(
    txs_list_downloads = function(...) peims_fake_downloads(),
    http_download = peims_fake_http_download,
    discover_peims_codes_url = function(year) {
      "https://example.org/budget2024d.zip"
    }
  )
  x <- txs_get_peims_finance(2024, "actual", "district", verbose = FALSE)
  bib <- txs_cite(x)
  expect_s3_class(bib, "bibentry")
  expect_match(format(bib), "PEIMS")

  generic <- txs_cite(source = "peims")
  expect_match(format(generic), "PEIMS Financial Data")
})

test_that("peims_parse_date is locale-proof and NA-safe", {
  expect_equal(peims_parse_date("04MAR2025"), as.Date("2025-03-04"))
  expect_equal(peims_parse_date(c("24JAN2024", "bogus", "")),
               as.Date(c("2024-01-24", NA, NA)))
})
