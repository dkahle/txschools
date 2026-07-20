test_that("norm_header and find_header_row handle layout drift", {
  expect_equal(norm_header("M & O Rate"), "m&o rate")
  expect_equal(norm_header("M&O RATE"), "m&o rate")
  raw <- tibble::tibble(a = c("title", "junk", "Taxing Unit ID"),
                        b = c("", "", "M&O Rate"))
  expect_equal(find_header_row(raw), 3L)
})

test_that("cdn_from_taxing_unit_id extracts 6-digit CDNs", {
  expect_equal(cdn_from_taxing_unit_id("161-920-02"), "161920")
  expect_true(is.na(cdn_from_taxing_unit_id("999")))
})

test_that("parse_comptroller_rates parses, filters, and dedupes", {
  out <- parse_comptroller_rates(
    fixture_path("comptroller_rates_small.xlsx"), year = 2024
  )
  expect_equal(nrow(out), 4L)  # split district deduped, junk row dropped
  expect_setequal(out$cdn, c("161920", "057905", "001902", "220901"))
  expect_equal(sum(out$cdn == "161920"), 1L)
  cs <- out[out$cdn == "161920", ]
  expect_equal(cs$mo_rate, 0.6774)
  expect_equal(cs$total_rate_src, 1.02138)
  expect_equal(unique(out$source), "comptroller")
  expect_equal(unique(out$year), 2024L)
})

test_that("tidy_tea_adopted reshapes the wide workbook", {
  out <- parse_tea_adopted(fixture_path("tea_adopted_small.xlsx"))
  expect_equal(nrow(out), 6L)  # 3 districts x 2 years
  expect_setequal(out$year, c(2006L, 2021L))
  # Integer CDNs are re-padded.
  expect_true("057905" %in% out$cdn)
  dallas06 <- out[out$cdn == "057905" & out$year == 2006, ]
  expect_equal(dallas06$mo_rate, 1.5)
  expect_equal(dallas06$is_rate, 0.0281)
  expect_true(all(is.na(out$total_rate_src)))
  expect_equal(unique(out$source), "tea")
})

test_that("merge_rate_sources: comptroller wins, tea backfills", {
  comp <- tibble::tibble(year = 2024L, cdn = "161920",
                         district_name = "China Spring ISD",
                         mo_rate = 0.6774, is_rate = 0.34398,
                         total_rate_src = 1.02138, source = "comptroller")
  tea <- tibble::tibble(
    year = c(2024L, 2024L, 2006L),
    cdn = c("161920", "057905", "161920"),
    district_name = "x", mo_rate = c(9, 0.96, 1.5),
    is_rate = 0, total_rate_src = NA_real_, source = "tea"
  )
  out <- merge_rate_sources(comp, tea)
  expect_equal(nrow(out), 3L)
  expect_equal(out$source[out$year == 2024 & out$cdn == "161920"],
               "comptroller")
  expect_equal(out$mo_rate[out$year == 2024 & out$cdn == "161920"], 0.6774)
  expect_equal(out$source[out$cdn == "057905"], "tea")
})

test_that("txs_get_tax_rates end to end, offline", {
  local_cache()
  testthat::local_mocked_bindings(
    http_download = function(url, dest, ...) {
      # Tax year 2020 was never published; mimic the 404.
      if (grepl("2020-school-district", url)) stop("HTTP 404 Not Found")
      src <- if (grepl("comptroller", url)) {
        fixture_path("comptroller_rates_small.xlsx")
      } else {
        fixture_path("tea_adopted_small.xlsx")
      }
      file.copy(src, dest, overwrite = TRUE)
      list(path = dest, sha256 = sha256_file(dest),
           size_bytes = file.size(dest), content_type = "application/xlsx",
           retrieved_at = iso8601_now(), source_url = url)
    }
  )

  suppressMessages(
    x <- txs_get_tax_rates(c(2006, 2021, 2024), verbose = FALSE)
  )
  expect_named(x, c("year", "school_year", "district", "district_name",
                    "mo_rate", "is_rate", "total_rate", "mcr",
                    "rate_source"))
  # 2024 from comptroller (fixture), 2006/2021 from TEA backfill.
  expect_equal(unique(x$rate_source[x$year == 2024]), "comptroller")
  expect_setequal(unique(x$rate_source[x$year != 2024]), "tea")
  expect_equal(x$school_year[x$year == 2021][1], "2020-21")
  # TEA total is derived mo + is; comptroller total from the file.
  expect_equal(x$total_rate[x$year == 2024 & x$district == "161920"],
               1.02138)
  expect_equal(x$total_rate[x$year == 2006 & x$district == "161920"],
               1.5 + 0.14)
  expect_true(all(is.na(x$mcr)))
  meta <- attr(x, "txschools")
  expect_equal(meta$source, "taxrates")
  expect_true(length(meta$files) >= 2)

  # Cached second call needs no network.
  testthat::local_mocked_bindings(
    http_download = function(...) stop("network should not be touched")
  )
  x2 <- txs_get_tax_rates(c(2006, 2021, 2024), verbose = FALSE)
  expect_equal(nrow(x2), nrow(x))

  # Cache inventory shows both slots, including the year-less TEA file.
  inv <- txs_cache_list()
  tr <- inv[inv$source == "taxrates", ]
  expect_setequal(unique(tr$data_type), c("comptroller", "tea"))
})

test_that("txs_get_tax_rates joins user-supplied MCR", {
  local_cache()
  testthat::local_mocked_bindings(
    http_download = function(url, dest, ...) {
      src <- if (grepl("comptroller", url)) {
        fixture_path("comptroller_rates_small.xlsx")
      } else {
        fixture_path("tea_adopted_small.xlsx")
      }
      file.copy(src, dest, overwrite = TRUE)
      list(path = dest, sha256 = "x", size_bytes = 1,
           content_type = "x", retrieved_at = iso8601_now(),
           source_url = url)
    }
  )
  x <- txs_get_tax_rates(2024, mcr = fixture_path("mcr_small.csv"),
                         verbose = FALSE)
  expect_equal(x$mcr[x$district == "161920"], 0.6692)
  expect_true(is.na(x$mcr[x$district == "001902"]))

  # Tibble input with year/district column names also works.
  x2 <- txs_get_tax_rates(
    2024,
    mcr = tibble::tibble(year = 2024, district = "161920", mcr = 0.7),
    verbose = FALSE
  )
  expect_equal(x2$mcr[x2$district == "161920"], 0.7)
  expect_error(
    txs_get_tax_rates(2024, mcr = tibble::tibble(a = 1), verbose = FALSE),
    "year"
  )
})

test_that("taxrates year validation and raw output", {
  expect_error(normalize_year(2005, source = "taxrates"), "out of range")
  local_cache()
  testthat::local_mocked_bindings(
    http_download = function(url, dest, ...) {
      file.copy(fixture_path("tea_adopted_small.xlsx"), dest,
                overwrite = TRUE)
      list(path = dest, sha256 = "x", size_bytes = 1, content_type = "x",
           retrieved_at = iso8601_now(), source_url = url)
    }
  )
  r <- txs_get_tax_rates(2006, output = "raw", verbose = FALSE)
  expect_true(all(c("cdn", "total_rate_src", "source") %in% names(r)))
})
