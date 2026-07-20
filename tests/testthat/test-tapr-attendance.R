test_that("tapr_sas_error_page detects broker error pages", {
  err <- withr::local_tempfile(fileext = ".html")
  writeLines(paste(
    "<html>Error reading SAS output. The SAS program did not produce",
    "any output.</html>"
  ), err)
  expect_true(tapr_sas_error_page(err))

  ok <- withr::local_tempfile(fileext = ".html")
  writeLines("<html><table><tr><td>Attendance Rate</td></tr></table></html>",
             ok)
  expect_false(tapr_sas_error_page(ok))
  expect_false(tapr_sas_error_page("no-such-file.html"))
})

test_that("download_tapr_semantic_page refuses to cache SAS error pages", {
  local_cache()
  testthat::local_mocked_bindings(
    http_download = function(url, dest, ...) {
      writeLines("Error reading SAS output", dest)
      list(path = dest, sha256 = "x", size_bytes = file.size(dest),
           content_type = "text/html", retrieved_at = iso8601_now(),
           source_url = url)
    }
  )
  expect_error(
    download_tapr_semantic_page(
      year = 2024, level = "campus", geography = "161920102",
      page_source = "graduation", prgopt = "reports/tapr/grad.sas",
      cache = TRUE, refresh = FALSE, timeout = 5, verbose = FALSE
    ),
    "error page"
  )
  # Nothing poisoned the cache.
  expect_length(
    list.files(txs_cache_dir(), pattern = "graduation", recursive = TRUE),
    0
  )
})

test_that("a previously cached SAS error page is treated as stale", {
  local_cache()
  dest <- cache_path("tapr", 2024, "campus", "html",
                     file = "tapr_campus_161920102_graduation.html")
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  writeLines("Error reading SAS output", dest)

  healthy <- paste0(
    "<html><table><tr><td>Attendance</td><td>Campus</td></tr>",
    "<tr><td>Attendance Rate</td><td>96.3%</td></tr></table></html>"
  )
  refetched <- FALSE
  testthat::local_mocked_bindings(
    http_download = function(url, dest, ...) {
      refetched <<- TRUE
      writeLines(healthy, dest)
      list(path = dest, sha256 = "x", size_bytes = file.size(dest),
           content_type = "text/html", retrieved_at = iso8601_now(),
           source_url = url)
    }
  )
  page <- download_tapr_semantic_page(
    year = 2024, level = "campus", geography = "161920102",
    page_source = "graduation", prgopt = "reports/tapr/grad.sas",
    cache = TRUE, refresh = FALSE, timeout = 5, verbose = FALSE
  )
  expect_true(refetched)
  expect_false(page$meta$used_cache)
  expect_gt(length(page$tables), 0)
})

test_that("the attendance dataset is the attendance slice of the grad page", {
  cat <- txs_list_tapr_datasets()
  expect_equal(cat$page_source[cat$key == "attendance"], "graduation")
  # The dead standalone endpoint is gone from the page catalog.
  expect_false("attendance" %in% tapr_page_catalog()$page_source)

  page <- list(
    tables = list(tibble::tibble(
      `Indicator` = c("Attendance Rate", "2024-25", "Longitudinal Rates",
                      "Graduation Rate", "Chronic Absenteeism"),
      `Campus` = c("Attendance Rate", "96.3%", "Longitudinal Rates",
                   "90%", "8.1%")
    )),
    links = tibble::tibble(),
    entity = list(),
    page_source = "graduation",
    meta = list(source_url = "x", retrieved_at = "t")
  )
  out <- extract_tapr_semantic_pages(
    pages = list(graduation = page), year = 2024, level = "campus",
    geography = "161920102", datasets = c("attendance", "graduation")
  )
  # Graduation keeps the whole page; attendance keeps only its slice.
  expect_true("Graduation Rate" %in% out$graduation$row_label)
  expect_false("Graduation Rate" %in% out$attendance$row_label)
  expect_true("2024-25" %in% out$attendance$row_label)  # under Attendance Rate
  expect_true("Chronic Absenteeism" %in% out$attendance$row_label)
})
