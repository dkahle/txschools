test_that("src_report_request builds the verified broker requests per era", {
  # HTML era (2004-2012): POST to alltypec.sas.
  req <- src_report_request(2011, "campus", "161920102", "html")
  expect_equal(req$method, "post")
  params <- decode_query_params(req$params)
  expect_equal(params$prgopt, "2011/src/alltypec.sas")
  expect_equal(params$year4, "2011")
  expect_equal(params$ptype, "HTML")
  expect_equal(params$search, "campnum")
  expect_equal(params$namenum, "161920102")

  # PDF era (2013-2019): GET to src.sas with the level-named id param.
  req <- src_report_request(2019, "campus", "161920102", "pdf")
  expect_equal(req$method, "get")
  params <- decode_query_params(req$params)
  expect_equal(params$prgopt, "2019/src/src.sas")
  expect_equal(params$cyr, "2019")
  expect_equal(params$level, "campus")
  expect_equal(params$campus, "161920102")

  req <- src_report_request(2019, "district", "161920", "pdf")
  params <- decode_query_params(req$params)
  expect_equal(params$district, "161920")
})

test_that("txs_get_src validates years and format availability", {
  expect_error(txs_get_src(2022, "campus", "161920102"),
               "txschools.gov")
  expect_error(txs_get_src(2003, "campus", "161920102"),
               "out of range")
  expect_error(txs_get_src(2016, "campus", "161920102", format = "html"),
               "PDF only")
  expect_error(txs_get_src(2011, "district", "161920", format = "html"),
               "PDF only")
  expect_error(txs_get_src(2011, "campus", NULL), "geography")
})

test_that("HTML-era SRC campus reports parse into a tidy masking-aware tibble", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  mockery::stub(txs_get_src, "http_download", function(url, dest, ...) {
    file.copy(fixture_path("src_2011_campus_report.html"), dest,
              overwrite = TRUE)
    list(path = dest, sha256 = sha256_file(dest),
         size_bytes = file.size(dest), content_type = "text/html",
         retrieved_at = iso8601_now(), source_url = url)
  })

  x <- txs_get_src(2011, "campus", "161920102", verbose = FALSE)
  expect_s3_class(x, "tbl_df")
  expect_gt(nrow(x), 150)
  expect_true(all(c("school_name", "district_name", "page", "section",
                    "measure", "row_label", "column", "value",
                    "value_num", "masked", "mask_code") %in% names(x)))
  expect_equal(unique(x$school_name), "CHINA SPRING EL")
  expect_equal(unique(x$district_name), "CHINA SPRING ISD")

  # Spot-check real values from the fixture.
  reading <- x[x$measure == "Reading/ELA" & x$row_label == "2011", ]
  expect_equal(
    reading$value[reading$column == "State Average"], "90%"
  )
  expect_equal(
    reading$value_num[reading$column == "District Average"], 96
  )
  expect_true(all(reading$masked[reading$column == "Asian"]))

  class_size <- x[x$section == "Class Size Averages by Grade and Subject" &
                    x$row_label == "Grade 1", ]
  expect_equal(
    class_size$value_num[class_size$column == "District Average"], 17.0
  )

  spend <- x[x$row_label == "Total Operating Expenditures", ]
  expect_equal(spend$value_num[spend$column == "School"], 4668)
  expect_true(spend$masked[spend$column == "School Group Average"])

  # Column names disambiguated from the stacked fixed-width header.
  expect_true(all(c("School (All Students)", "African American",
                    "Pacific Islander", "Two or More Races") %in% x$column))

  # Provenance travels with the result.
  meta <- attr(x, "txschools")
  expect_equal(meta$source, "src")
  expect_equal(meta$header$school_number, "161920102")
  expect_equal(meta$header$school_rating, "Recognized")

  # Cached copy is reused.
  mockery::stub(txs_get_src, "http_download",
                function(...) stop("should not be called"))
  x2 <- txs_get_src(2011, "campus", "161920102", verbose = FALSE)
  expect_true(attr(x2, "txschools")$used_cache)
})

test_that("PDF-era SRC reports are cached and described", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_pdf <- function(url, dest, ...) {
    writeBin(c(charToRaw("%PDF-1.5"), as.raw(rep(0, 32))), dest)
    list(path = dest, sha256 = sha256_file(dest),
         size_bytes = file.size(dest), content_type = "application/pdf",
         retrieved_at = iso8601_now(), source_url = url)
  }
  mockery::stub(txs_get_src, "http_download", fake_pdf)

  x <- txs_get_src(2019, "campus", "161920102", verbose = FALSE)
  expect_equal(nrow(x), 1L)
  expect_equal(x$file_format, "pdf")
  expect_true(file.exists(x$path))
  expect_match(x$path, "src_campus_161920102_2019\\.pdf$")
})

test_that("txs_get_src rejects broker error pages", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  mockery::stub(txs_get_src, "http_download", function(url, dest, ...) {
    writeLines("<HTML><TITLE>Error reading SAS output</TITLE></HTML>", dest)
    list(path = dest, sha256 = sha256_file(dest),
         size_bytes = file.size(dest), content_type = "text/html",
         retrieved_at = iso8601_now(), source_url = url)
  })
  expect_error(
    txs_get_src(2011, "campus", "000000000", verbose = FALSE),
    "did not return an SRC"
  )
})
