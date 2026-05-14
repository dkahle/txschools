test_that("txs_cache_dir honors the option override", {
  withr::with_options(list(txschools.cache_dir = tempdir()), {
    expect_identical(
      normalizePath(txs_cache_dir(), winslash = "/", mustWork = FALSE),
      normalizePath(tempdir(),       winslash = "/", mustWork = FALSE)
    )
  })
})

test_that("cache_list returns an empty tibble on an empty cache", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  out <- txs_cache_list()
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})

test_that("sidecar round-trips and cache_list picks it up", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  cp <- cache_path("tapr", 2023, "campus", "advanced", file = "campadv.zip")
  dir.create(dirname(cp), recursive = TRUE)
  writeLines("dummy", cp)
  meta <- list(
    source = "tapr", year = 2023, school_year = "2023-24",
    level = "campus", data_type = "advanced", file_format = "csv",
    source_url = "https://example.org/x.zip",
    retrieved_at = iso8601_now(),
    sha256 = sha256_file(cp),
    size_bytes = file.size(cp),
    content_type = "application/zip"
  )
  write_sidecar(cp, meta)

  inv <- txs_cache_list()
  expect_equal(nrow(inv), 1)
  expect_equal(inv$source[1], "tapr")
  expect_equal(inv$year[1], 2023L)
  expect_equal(inv$level[1], "campus")
  expect_equal(inv$file[1], "campadv.zip")
})

test_that("cache_delete with ask=FALSE removes file and sidecar", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  cp <- cache_path("tapr", 2023, "campus", "advanced", file = "a.csv")
  dir.create(dirname(cp), recursive = TRUE)
  writeLines("data", cp)
  write_sidecar(cp, list(
    source = "tapr", year = 2023, level = "campus",
    data_type = "advanced", file_format = "csv",
    source_url = "u", retrieved_at = iso8601_now(),
    sha256 = sha256_file(cp), size_bytes = file.size(cp)
  ))

  expect_equal(nrow(txs_cache_list()), 1)
  invisible(txs_cache_delete(year = 2023, source = "tapr", ask = FALSE))
  expect_false(file.exists(cp))
  expect_false(file.exists(sidecar_path(cp)))
  expect_equal(nrow(txs_cache_list()), 0)
})
