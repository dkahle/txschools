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

test_that("txs_get_tapr_dictionary refreshes stale discovery when missing", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  old_downloads <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "advanced", dataset = "REF",
    file_format = "csv", label = "TAPR advanced REF (campus)",
    method = "get", url = "https://example.org/broker",
    params = NA_character_
  )
  new_downloads <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "dictionary", dataset = NA_character_,
    file_format = "xlsx", label = "TAPR_campus_2024.xlsx",
    method = "get",
    url = "https://example.org/xplore/TAPR_campus_2024.xlsx",
    params = NA_character_
  )
  mockery::stub(txs_get_tapr_dictionary, "txs_list_downloads",
                function(..., refresh = FALSE) {
                  if (isTRUE(refresh)) new_downloads else old_downloads
                })
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
})

test_that("HTML TAPR dictionary detail pages parse to dictionary rows", {
  master <- paste0(
    '<a href="../../2016/download/dref.html">District Reference</a>',
    '<a href="../../2016/download/diststaar1a.html">',
    'District STAAR Data - Level II Satisfactory Standard</a>',
    '<a href="../../2016/download/cref.html">Campus Reference</a>'
  )
  links <- parse_tapr_html_reference_detail_links(
    master,
    page_url = "https://rptsvr1.tea.texas.gov/perfreport/tapr/2016/download/taprref.html"
  )
  expect_setequal(links$dataset, c("DREF", "DISTSTAAR1A", "CREF"))
  expect_setequal(links$level, c("district", "campus"))

  detail <- paste0(
    "<table>",
    "<tr><th>NAME</th><th>TYPE</th><th>LENGTH</th><th>LABEL</th></tr>",
    "<tr><td>DA03ARE1S16R</td><td>Numeric</td><td>8</td>",
    "<td>District 2016 Index 1: Index 1 (Phase-in Level II &amp; PM_ELL), ",
    "Grade 3, All Students, STAAR Reading/ELA Rate</td></tr>",
    "</table>"
  )
  dict <- parse_tapr_html_dictionary_detail(
    detail, year = 2016, level = "district", dataset = "DISTSTAAR1A"
  )
  expect_named(dict, c("year", "school_year", "level", "sheet",
                       "dataset", "variable", "label"))
  expect_equal(dict$variable, "DA03ARE1S16R")
  expect_equal(dict$dataset, "DISTSTAAR1A")
  expect_match(dict$label, "Grade 3")
})

test_that("txs_get_tapr_dictionary gives an informative missing-dictionary error", {
  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2025L, school_year = "2024-25",
    level = "district", data_type = "advanced", dataset = "STAAR1",
    file_format = "csv", label = "TAPR advanced STAAR1 (district)",
    method = "get",
    url = "https://example.org/broker",
    params = NA_character_
  )
  mockery::stub(txs_get_tapr_dictionary, "txs_list_downloads",
                function(...) fake_downloads)

  expect_error(
    txs_get_tapr_dictionary(2025, "district", verbose = FALSE),
    "Advanced data files were discovered.*refresh = TRUE"
  )
})
