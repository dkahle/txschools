# Live smoke tests against TEA's public site. Skipped unless
# TXS_LIVE=true so CRAN/CI stay offline; run them with
#   TXS_LIVE=true Rscript -e 'devtools::test(filter = "live")'
# These are the guard against fixture drift: every claimed data path is
# exercised for real, politely (~10 rate-limited requests total).

skip_if_not_live <- function() {
  testthat::skip_if_not(
    identical(Sys.getenv("TXS_LIVE"), "true"),
    "Set TXS_LIVE=true to run live TEA smoke tests."
  )
}

test_that("live: semantic TAPR pull (China Spring Elementary)", {
  skip_if_not_live()
  local_cache()
  x <- txs_get_tapr(2025, "campus", "161920102",
                    datasets = c("grade", "sex"), verbose = FALSE)
  expect_gt(nrow(x$grade), 0)
  expect_gt(nrow(x$sex), 0)
  expect_equal(unique(x$sex$entity_name), "CHINA SPRING EL")
  expect_equal(unique(x$sex$district_name), "CHINA SPRING ISD")
})

test_that("live: TAPR download discovery finds advanced datasets", {
  skip_if_not_live()
  local_cache()
  dl <- txs_list_downloads(2024, "tapr")
  expect_gt(sum(dl$data_type == "advanced"), 4 * 15)
  expect_equal(sum(dl$data_type == "dictionary"), 4)
  expect_true("REF" %in% dl$dataset)
})

test_that("live: TAPR advanced state file downloads as CSV", {
  skip_if_not_live()
  local_cache()
  df <- txs_get_tapr_file(2024, "state", dataset = "STAAR1",
                          output = "raw", verbose = FALSE)
  expect_gt(ncol(df), 10)
  expect_equal(nrow(df), 1L)
})

test_that("live: TAPR dictionary workbook parses", {
  skip_if_not_live()
  local_cache()
  dict <- txs_get_tapr_dictionary(2024, "state", verbose = FALSE)
  expect_gt(nrow(dict), 100)
})

test_that("live: AEIS state file downloads via the POST CGI", {
  skip_if_not_live()
  local_cache()
  df <- txs_get_aeis(2011, "district", dataset = "ref",
                     geography = "161920", output = "raw", verbose = FALSE)
  expect_equal(nrow(df), 1L)
  expect_true("DISTNAME" %in% toupper(names(df)))
})

test_that("live: SRC HTML-era campus report parses", {
  skip_if_not_live()
  local_cache()
  x <- txs_get_src(2011, "campus", "161920102", verbose = FALSE)
  expect_gt(nrow(x), 100)
  expect_equal(unique(x$school_name), "CHINA SPRING EL")
})

test_that("live: SRC PDF-era report downloads", {
  skip_if_not_live()
  local_cache()
  x <- txs_get_src(2019, "campus", "161920102", verbose = FALSE)
  expect_true(file.exists(x$path))
  expect_match(read_head_bytes(x$path, 8), "^%PDF")
})

test_that("live: directory lookup resolves names to CDC numbers", {
  skip_if_not_live()
  local_cache()
  hits <- txs_find_campus("china spring", year = 2024)
  expect_true("161920102" %in% hits$id)
  expect_equal(unique(hits$district_name), "CHINA SPRING ISD")
})
