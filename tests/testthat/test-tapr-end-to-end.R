# End-to-end TAPR exercise, but with http_download stubbed so we read
# a fixture CSV instead of going to the network.

test_that("txs_get_tapr stubbed end-to-end returns tidy with masking", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_url <- "https://example.org/perfreport/tapr/2023-24/download/campadv.csv"
  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2023L, school_year = "2023-24",
    level = "campus", data_type = "advanced",
    file_format = "csv",
    label = "Campus Advanced (CSV)", url = fake_url
  )
  mockery::stub(txs_get_tapr, "txs_list_downloads", function(...) fake_downloads)
  mockery::stub(txs_get_tapr, "http_download", function(url, dest, ...) {
    file.copy(fixture_path("synthetic_campus_advanced.csv"), dest, overwrite = TRUE)
    list(
      path = dest, sha256 = sha256_file(dest),
      size_bytes = file.size(dest),
      content_type = "text/csv", retrieved_at = iso8601_now(),
      source_url = url
    )
  })

  df <- txs_get_tapr(
    2023, level = "campus",
    data_type = "advanced", file_format = "csv",
    output = "tidy", verbose = FALSE
  )

  expect_s3_class(df, "tbl_df")
  meta <- attr(df, "txschools")
  expect_equal(meta$source, "tapr")
  expect_equal(meta$year, 2023L)
  expect_equal(meta$school_year, "2023-24")
  expect_equal(meta$source_url, fake_url)
  expect_true(nzchar(meta$sha256))
  expect_match(meta$cache_path, "tapr.*2023-24.*campus.*advanced")

  # Masking preserved.
  expect_true(any(df$value == "*"))
  expect_true(any(df$value == "."))
  expect_true(any(df$masked))
  expect_true(all(is.na(df$value_num[df$masked])))

  # Sidecar written.
  expect_true(file.exists(sidecar_path(meta$cache_path)))

  # Re-call: cache hit, no http call.
  mockery::stub(txs_get_tapr, "http_download",
                function(...) stop("should not be called"))
  df2 <- txs_get_tapr(
    2023, level = "campus",
    data_type = "advanced", file_format = "csv",
    output = "tidy", verbose = FALSE
  )
  expect_true(attr(df2, "txschools")$used_cache)
  expect_equal(attr(df2, "txschools")$sha256,
               attr(df, "txschools")$sha256)
})

test_that("txs_get_tapr filters by geography", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_url <- "https://example.org/x/campadv.csv"
  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2023L, school_year = "2023-24",
    level = "campus", data_type = "advanced", file_format = "csv",
    label = "Campus Advanced (CSV)", url = fake_url
  )
  mockery::stub(txs_get_tapr, "txs_list_downloads", function(...) fake_downloads)
  mockery::stub(txs_get_tapr, "http_download", function(url, dest, ...) {
    file.copy(fixture_path("synthetic_campus_advanced.csv"), dest, overwrite = TRUE)
    list(path = dest, sha256 = sha256_file(dest),
         size_bytes = file.size(dest), content_type = "text/csv",
         retrieved_at = iso8601_now(), source_url = url)
  })

  df <- txs_get_tapr(
    2023, level = "campus", geography = "000000001",
    data_type = "advanced", file_format = "csv",
    output = "raw", verbose = FALSE
  )
  expect_equal(nrow(df), 1L)
  expect_equal(df$CAMPUS, "000000001")
})
