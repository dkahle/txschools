test_that("classify_level matches campus/district/region/state prefixes", {
  px <- list(
    campus   = c("cs", "camp", "ca"),
    district = c("dis", "dist", "dt"),
    region   = c("reg"),
    state    = c("state", "st")
  )
  expect_identical(classify_level("campadv.zip", px), "campus")
  expect_identical(classify_level("cs.csv",      px), "campus")
  expect_identical(classify_level("distadv.zip", px), "district")
  expect_identical(classify_level("regadv.csv",  px), "region")
  expect_identical(classify_level("stateadv.csv",px), "state")
  expect_true(is.na(classify_level("glossary.pdf", px)))
})

test_that("classify_format maps extensions", {
  expect_identical(classify_format("a.csv"),  "csv")
  expect_identical(classify_format("a.xlsx"), "xlsx")
  expect_identical(classify_format("a.dat"),  "txt")
  expect_identical(classify_format("a.zip"),  "csv")
})

test_that("parse_links_html classifies anchors from fixture HTML", {
  html <- fixture_html("tapr_2023_advanced_download.html")
  rows <- parse_links_html(
    html_str = html,
    page_url = "https://rptsvr1.tea.texas.gov/perfreport/tapr/2023-24/xplore/Index.html",
    year = 2023, source = "tapr", data_type = "advanced",
    level_prefixes = txschools:::catalog_source("tapr")$level_prefixes
  )
  expect_true(length(rows) > 0)
  levels <- vapply(rows, function(r) r$level %||% NA_character_, character(1))
  dtypes <- vapply(rows, function(r) r$data_type %||% NA_character_, character(1))
  expect_true("campus" %in% levels)
  expect_true("district" %in% levels)
  expect_true(all(dtypes == "advanced"))
  # Glossary PDF should be excluded by extension filter.
  urls <- vapply(rows, function(r) r$url, character(1))
  expect_false(any(grepl("glossary\\.pdf", urls)))
})

test_that("scrape_tapr_download_pages parses fixture HTML when fetch is mocked", {
  mockery::stub(scrape_tapr_download_pages, "extract_links_from_page",
                function(page_url, year, source, data_type, level_prefixes) {
                  fixture <- if (grepl("xplore|advance", tolower(page_url))) {
                    "tapr_2023_advanced_download.html"
                  } else {
                    "tapr_2023_basic_download.html"
                  }
                  parse_links_html(
                    fixture_html(fixture),
                    page_url = page_url,
                    year = year, source = source,
                    data_type = data_type,
                    level_prefixes = level_prefixes
                  )
                })
  rows <- scrape_tapr_download_pages(2023)
  expect_true(length(rows) > 0)
  dtypes <- vapply(rows, function(r) r$data_type %||% NA_character_, character(1))
  expect_true("advanced" %in% dtypes)
  expect_true("basic"    %in% dtypes)
})

test_that("txs_list_downloads uses the catalog fallback when scraping yields nothing", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  mockery::stub(discover_tapr_downloads, "scrape_tapr_download_pages",
                function(year) list())
  rows <- discover_tapr_downloads(2023)
  expect_true(length(rows) > 0)
  # Catalog entries for 2023 should produce campus + district + advanced.
  combos <- vapply(
    rows, function(r) paste(r$level, r$data_type, sep = "/"),
    character(1)
  )
  expect_true("campus/advanced" %in% combos)
  expect_true("district/advanced" %in% combos)
})
