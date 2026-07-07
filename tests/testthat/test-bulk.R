test_that("txs_bulk_plan produces one row per (year, level, dataset) combo", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_downloads <- function(year, source, refresh = FALSE) {
    yr <- as.integer(year)
    grid <- expand.grid(
      level = c("campus", "district"), dataset = c("REF", "GRAD"),
      stringsAsFactors = FALSE
    )
    tibble::tibble(
      source      = "tapr",
      year        = yr,
      school_year = year_label(yr),
      level       = grid$level,
      data_type   = "advanced",
      dataset     = grid$dataset,
      file_format = "csv",
      label       = "fixture",
      method      = "get",
      url         = sprintf("https://x/%d/broker", yr),
      params      = sprintf("sumlev=C&setpick=%s", grid$dataset)
    )
  }
  mockery::stub(txs_bulk_plan, "txs_list_downloads", fake_downloads)

  plan <- txs_bulk_plan(2023:2024, levels = c("campus", "district"))
  expect_equal(nrow(plan), 2 * 2 * 2)
  expect_setequal(plan$year, c(2023L, 2024L))
  expect_setequal(plan$dataset, c("REF", "GRAD"))
  expect_false(any(plan$exists_in_cache))
  expect_true(all(!is.na(plan$url)))

  # Dataset filter narrows the plan.
  plan_ref <- txs_bulk_plan(2024, levels = "campus", datasets = "ref")
  expect_equal(nrow(plan_ref), 1)
  expect_equal(plan_ref$dataset, "REF")
})

test_that("txs_bulk_download writes sidecars and respects delay=0", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  plan <- tibble::tibble(
    source = rep("tapr", 2), year = c(2023L, 2024L),
    school_year = c("2022-23", "2023-24"),
    level = "campus", data_type = "advanced", dataset = "REF",
    file_format = "csv", method = "get",
    url = c("https://x/2023/c.csv", "https://x/2024/c.csv"),
    params = NA_character_,
    cache_path = c(
      cache_path("tapr", 2023, "campus", "advanced", file = "c.csv"),
      cache_path("tapr", 2024, "campus", "advanced", file = "c.csv")
    ),
    exists_in_cache = c(FALSE, FALSE)
  )
  mockery::stub(txs_bulk_download, "http_download", function(url, dest, ...) {
    file.copy(fixture_path("synthetic_campus_advanced.csv"), dest, overwrite = TRUE)
    list(path = dest, sha256 = sha256_file(dest),
         size_bytes = file.size(dest), content_type = "text/csv",
         retrieved_at = iso8601_now(), source_url = url)
  })

  done <- txs_bulk_download(plan, delay = 0)
  expect_setequal(done$status, c("downloaded"))
  expect_true(all(!is.na(done$sha256)))
  for (cp in done$cache_path) {
    expect_true(file.exists(cp))
    expect_true(file.exists(sidecar_path(cp)))
  }

  # Second run hits the cache.
  plan2 <- plan
  plan2$exists_in_cache <- TRUE
  done2 <- txs_bulk_download(plan2, delay = 0)
  expect_setequal(done2$status, "cached")
})

test_that("txs_bulk_download records errors without throwing when stop_on_error=FALSE", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  plan <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "advanced", dataset = "REF",
    file_format = "csv", method = "get",
    url = "https://x/2024/c.csv", params = NA_character_,
    cache_path = cache_path("tapr", 2024, "campus", "advanced", file = "c.csv"),
    exists_in_cache = FALSE
  )
  mockery::stub(txs_bulk_download, "http_download",
                function(...) stop("boom"))
  done <- txs_bulk_download(plan, delay = 0, stop_on_error = FALSE)
  expect_equal(done$status, "error")
  expect_match(done$error, "boom")
})

test_that("txs_bulk_download flags broker HTML responses as errors", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  plan <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "state", data_type = "advanced", dataset = "REF",
    file_format = "csv", method = "get",
    url = "https://x/broker", params = NA_character_,
    cache_path = cache_path("tapr", 2024, "state", "advanced", file = "c.csv"),
    exists_in_cache = FALSE
  )
  mockery::stub(txs_bulk_download, "http_download", function(url, dest, ...) {
    file.copy(fixture_path("broker_error_state_ref.html"), dest, overwrite = TRUE)
    list(path = dest, sha256 = sha256_file(dest),
         size_bytes = file.size(dest), content_type = "text/html",
         retrieved_at = iso8601_now(), source_url = url)
  })
  done <- txs_bulk_download(plan, delay = 0, stop_on_error = FALSE)
  expect_equal(done$status, "error")
  expect_match(done$error, "report page instead of data")
  expect_false(file.exists(plan$cache_path))
})
