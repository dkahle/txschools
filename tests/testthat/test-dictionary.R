test_that("read_tapr_dictionary tidies the statewide workbook", {
  dict <- read_tapr_dictionary(
    fixture_path("tapr_dictionary_campus_2024.xlsx"),
    year = 2024, level = "campus"
  )
  expect_s3_class(dict, "tbl_df")
  expect_named(dict, c("year", "school_year", "level", "sheet",
                       "dataset", "variable", "label"))
  expect_gt(nrow(dict), 100)
  expect_true("cref" %in% dict$sheet)
  expect_true("CAMPNAME" %in% dict$variable)
  ref <- dict[dict$variable == "CAMPNAME", ]
  expect_equal(ref$label[[1]], "Campus Name")
})

test_that("txs_get_tapr_dictionary downloads, caches, and parses", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "dictionary", dataset = NA_character_,
    file_format = "xlsx", label = "TAPR_campus_2024.xlsx",
    method = "get",
    url = "https://example.org/xplore/TAPR_campus_2024.xlsx",
    params = NA_character_
  )
  mockery::stub(txs_get_tapr_dictionary, "txs_list_downloads",
                function(...) fake_downloads)
  mockery::stub(txs_get_tapr_dictionary, "http_download",
                function(url, dest, ...) {
                  file.copy(fixture_path("tapr_dictionary_campus_2024.xlsx"),
                            dest, overwrite = TRUE)
                  list(path = dest, sha256 = sha256_file(dest),
                       size_bytes = file.size(dest),
                       content_type = "application/vnd.ms-excel",
                       retrieved_at = iso8601_now(), source_url = url)
                })

  dict <- txs_get_tapr_dictionary(2024, "campus", verbose = FALSE)
  expect_gt(nrow(dict), 100)
  meta <- attr(dict, "txschools")
  expect_equal(meta$data_type, "dictionary")
  expect_true(file.exists(meta$cache_path))

  mockery::stub(txs_get_tapr_dictionary, "http_download",
                function(...) stop("should not be called"))
  dict2 <- txs_get_tapr_dictionary(2024, "campus", verbose = FALSE)
  expect_true(attr(dict2, "txschools")$used_cache)
})
