test_that("classify_level matches level tokens anywhere in the filename", {
  tokens <- txschools:::catalog_source("tapr")$level_tokens
  # Real 2024+ dictionary workbook names.
  expect_identical(classify_level("TAPR_campus_2024.xlsx", tokens), "campus")
  expect_identical(classify_level("TAPR_district_2024.xlsx", tokens), "district")
  expect_identical(classify_level("TAPR_region_2024.xlsx", tokens), "region")
  expect_identical(classify_level("TAPR_state_2024.xlsx", tokens), "state")
  # Legacy prefix-style names.
  expect_identical(classify_level("cs.csv", tokens), "campus")
  expect_identical(classify_level("campadv.zip", tokens), "campus")
  expect_identical(classify_level("distadv.zip", tokens), "district")
  expect_identical(classify_level("regadv.csv", tokens), "region")
  expect_identical(classify_level("stateadv.csv", tokens), "state")
  expect_true(is.na(classify_level("glossary.pdf", tokens)))
})

test_that("classify_format maps extensions", {
  expect_identical(classify_format("a.csv"),  "csv")
  expect_identical(classify_format("a.xlsx"), "xlsx")
  expect_identical(classify_format("a.dat"),  "txt")
  expect_identical(classify_format("a.zip"),  "csv")
})

test_that("parse_tapr_basic_page finds the dictionary workbooks (2024 page)", {
  rows <- parse_tapr_basic_page(
    fixture_html("tapr_2024_basic_download.html"),
    page_url = "https://rptsvr1.tea.texas.gov/perfreport/tapr/2024/Basic%20Download/DownloadSelData.html",
    year = 2024,
    level_tokens = txschools:::catalog_source("tapr")$level_tokens
  )
  expect_length(rows, 4)
  levels <- vapply(rows, function(r) r$level, character(1))
  expect_setequal(levels, c("campus", "district", "region", "state"))
  expect_true(all(vapply(rows, function(r) r$data_type, character(1)) ==
                    "dictionary"))
  expect_true(all(grepl("TAPR_.*_2024\\.xlsx$",
                        vapply(rows, function(r) r$url, character(1)))))
})

test_that("parse_tapr_advanced_page parses the 2024 GET broker form", {
  rows <- parse_tapr_advanced_page(
    fixture_html("tapr_2024_advanced_download.html"),
    page_url = "https://rptsvr1.tea.texas.gov/perfreport/tapr/2024/Advance%20Download/download-data-adv.html",
    year = 2024
  )
  expect_length(rows, 4 * 18)
  r <- rows[[1]]
  expect_equal(r$data_type, "advanced")
  expect_equal(r$file_format, "csv")
  expect_equal(r$method, "get")
  expect_match(r$url, "/cgi/sas/broker$")
  params <- decode_query_params(r$params)
  expect_equal(params$`_program`, "perfrept.perfmast.sas")
  expect_equal(params$ccyy, "2024")
  expect_match(params$prgopt, "getdata_2024\\.sas$")
  expect_true(params$sumlev %in% c("C", "D", "R", "S"))
  datasets <- unique(vapply(rows, function(r) r$dataset, character(1)))
  expect_true(all(c("REF", "STAAR1", "GRAD", "PKEFF") %in% datasets))
})

test_that("parse_tapr_advanced_page parses the pre-2024 POST broker form", {
  for (fixture in c("tapr_2023_advanced_form.html",
                    "tapr_2018_advanced_form.html")) {
    year <- if (grepl("2023", fixture)) 2023 else 2018
    rows <- parse_tapr_advanced_page(
      fixture_html(fixture),
      page_url = sprintf(
        "https://rptsvr1.tea.texas.gov/perfreport/tapr/%d/download/DownloadData.html",
        year
      ),
      year = year
    )
    expect_gt(length(rows), 4 * 15)
    r <- rows[[1]]
    expect_equal(r$method, "post")
    params <- decode_query_params(r$params)
    expect_equal(params$year4, as.character(year))
    expect_match(params$prgopt, "tapr_download\\.sas$")
    expect_true("REF" %in% vapply(rows, function(r) r$dataset, character(1)))
  }
})

test_that("discover_tapr_downloads combines dictionary and advanced rows", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  mockery::stub(discover_tapr_downloads, "fetch_html", function(page_url) {
    if (grepl("Basic|xplore", page_url)) {
      fixture_html("tapr_2024_basic_download.html")
    } else {
      fixture_html("tapr_2024_advanced_download.html")
    }
  })
  rows <- discover_tapr_downloads(2024)
  dtypes <- vapply(rows, function(r) r$data_type, character(1))
  expect_equal(sum(dtypes == "dictionary"), 4)
  expect_equal(sum(dtypes == "advanced"), 4 * 18)
})

test_that("discovery falls back to catalog broker rows when pages fail", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  mockery::stub(discover_tapr_downloads, "fetch_html",
                function(page_url) stop("offline"))
  rows <- discover_tapr_downloads(2024)
  dtypes <- vapply(rows, function(r) r$data_type, character(1))
  expect_true(all(dtypes == "advanced"))
  expect_gt(length(rows), 4 * 15)
  params <- decode_query_params(rows[[1]]$params)
  expect_equal(params$ccyy, "2024")

  # Pre-2024 fallback uses the POST convention.
  rows18 <- discover_tapr_downloads(2018)
  expect_equal(rows18[[1]]$method, "post")
  params18 <- decode_query_params(rows18[[1]]$params)
  expect_equal(params18$year4, "2018")
})

test_that("parse_aeis_download_form builds POST rows per level and file", {
  rows <- parse_aeis_download_form(
    fixture_html("aeis_2011_download_form.html"),
    page_url = "https://rptsvr1.tea.texas.gov/perfreport/aeis/2011/DownloadData.html",
    year = 2011
  )
  expect_equal(length(rows), 4 * 26)
  r <- rows[[1]]
  expect_equal(r$method, "post")
  expect_match(r$url, "2011aeis\\.cgi$")
  params <- decode_query_params(r$params)
  expect_equal(params$suf, ".dat")
  expect_true(params$level %in% c("c", "d", "r", "s"))
  datasets <- vapply(rows, function(r) r$dataset, character(1))
  expect_true(all(c("ref", "fin", "staf", "stud") %in% datasets))
})

test_that("catalog_url expands TEA paths and encodes spaces", {
  cat <- txschools:::catalog_source("tapr")
  expect_equal(
    catalog_url(cat$landing, cat$base, 2024),
    "https://rptsvr1.tea.texas.gov/perfreport/tapr/2024/index.html"
  )
  expect_equal(
    catalog_url(cat$basic_pages[[1]], cat$base, 2024),
    "https://rptsvr1.tea.texas.gov/perfreport/tapr/2024/Basic%20Download/DownloadSelData.html"
  )
})

test_that("query param helpers round-trip", {
  params <- list(`_service` = "marykay", sumlev = "C",
                 prgopt = "2024/tapr/Advanced Download/getdata_2024.sas")
  encoded <- encode_query_params(params)
  expect_type(encoded, "character")
  expect_identical(decode_query_params(encoded), params)
  expect_identical(decode_query_params(NULL), list())
  expect_identical(decode_query_params(NA_character_), list())
  expect_identical(encode_query_params(NULL), NA_character_)
})
