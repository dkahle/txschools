# End-to-end TAPR exercises with downloads stubbed to fixture files.

fake_tapr_download <- function(url, dest, ...) {
  src <- if (grepl("\\.csv", url, ignore.case = TRUE)) {
    fixture_path("synthetic_campus_advanced.csv")
  } else if (grepl("student", url, ignore.case = TRUE)) {
    fixture_path("tapr_student_report.html")
  } else if (grepl("perf_addsg", url, ignore.case = TRUE)) {
    fixture_path("tapr_staar_performance.html")
  } else if (grepl("progress", url, ignore.case = TRUE)) {
    fixture_path("tapr_staar_progress.html")
  } else {
    NULL
  }

  if (is.null(src)) {
    writeLines("<!doctype html><html><body>No TAPR table</body></html>", dest)
  } else {
    file.copy(src, dest, overwrite = TRUE)
  }
  list(
    path = dest,
    sha256 = sha256_file(dest),
    size_bytes = file.size(dest),
    content_type = if (grepl("\\.csv", url, ignore.case = TRUE)) {
      "text/csv"
    } else {
      "text/html"
    },
    retrieved_at = iso8601_now(),
    source_url = url
  )
}

cache_tapr_page_fixture <- function(year, geography, page_source, fixture,
                                    prgopt = paste0("reports/tapr/", page_source, ".sas")) {
  cp <- cache_path(
    "tapr", year, "campus", "html",
    file = tapr_html_report_filename("campus", geography, page_source)
  )
  dir.create(dirname(cp), recursive = TRUE, showWarnings = FALSE)
  file.copy(fixture_path(fixture), cp, overwrite = TRUE)
  write_sidecar(cp, list(
    source = "tapr",
    year = as.integer(year),
    school_year = year_label(year),
    level = "campus",
    geography = geography,
    page_source = page_source,
    prgopt = prgopt,
    data_type = "semantic",
    file_format = "html",
    source_url = tapr_html_report_url(year, "campus", geography, prgopt = prgopt),
    retrieved_at = iso8601_now(),
    sha256 = sha256_file(cp),
    size_bytes = file.size(cp),
    content_type = "text/html"
  ))
  cp
}

test_that("txs_get_tapr_file stubbed end-to-end returns tidy with masking", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_url <- "https://example.org/perfreport/tapr/2024/download/campadv.csv"
  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "advanced",
    file_format = "csv",
    label = "Campus Advanced (CSV)", url = fake_url
  )
  mockery::stub(txs_get_tapr_file, "txs_list_downloads", function(...) fake_downloads)
  mockery::stub(txs_get_tapr_file, "http_download", fake_tapr_download)

  df <- txs_get_tapr_file(
    2024, level = "campus",
    data_type = "advanced", file_format = "csv",
    output = "tidy", verbose = FALSE
  )

  expect_s3_class(df, "tbl_df")
  meta <- attr(df, "txschools")
  expect_equal(meta$source, "tapr")
  expect_equal(meta$year, 2024L)
  expect_equal(meta$school_year, "2023-24")
  expect_equal(meta$source_url, fake_url)
  expect_true(nzchar(meta$sha256))
  expect_match(meta$cache_path, "tapr.*2023-24.*campus.*advanced")

  expect_true(any(df$value == "*"))
  expect_true(any(df$value == "."))
  expect_true(any(df$masked))
  expect_true(all(is.na(df$value_num[df$masked])))
  expect_true(file.exists(sidecar_path(meta$cache_path)))

  mockery::stub(txs_get_tapr_file, "http_download",
                function(...) stop("should not be called"))
  df2 <- txs_get_tapr_file(
    2024, level = "campus",
    data_type = "advanced", file_format = "csv",
    output = "tidy", verbose = FALSE
  )
  expect_true(attr(df2, "txschools")$used_cache)
  expect_equal(attr(df2, "txschools")$sha256,
               attr(df, "txschools")$sha256)
})

test_that("txs_get_tapr_file filters by geography", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_url <- "https://example.org/x/campadv.csv"
  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "advanced", file_format = "csv",
    label = "Campus Advanced (CSV)", url = fake_url
  )
  mockery::stub(txs_get_tapr_file, "txs_list_downloads", function(...) fake_downloads)
  mockery::stub(txs_get_tapr_file, "http_download", fake_tapr_download)

  df <- txs_get_tapr_file(
    2024, level = "campus", geography = "000000001",
    data_type = "advanced", file_format = "csv",
    output = "raw", verbose = FALSE
  )
  expect_equal(nrow(df), 1L)
  expect_equal(df$CAMPUS, "000000001")
})

test_that("txs_get_tapr_file spec defaults use campus rates and cache=FALSE is temporary", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  fake_url <- "https://example.org/perfreport/tapr/2024/download/cs.csv"
  fake_downloads <- tibble::tibble(
    source = "tapr", year = 2024L, school_year = "2023-24",
    level = "campus", data_type = "rates",
    file_format = "csv",
    label = "Campus Rates (CSV)", url = fake_url
  )
  mockery::stub(txs_get_tapr_file, "txs_list_downloads", function(...) fake_downloads)
  mockery::stub(txs_get_tapr_file, "http_download", fake_tapr_download)

  df <- txs_get_tapr_file(2024, file_format = "csv", cache = FALSE,
                          output = "raw", verbose = FALSE)
  meta <- attr(df, "txschools")
  expect_equal(meta$level, "campus")
  expect_equal(meta$data_type, "rates")
  expect_length(list.files(dir, all.files = TRUE, no.. = TRUE), 0)
})

test_that("txs_get_tapr_file parses cached public HTML report pages", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  cp <- cache_path(
    "tapr", 2025, "campus", "rates",
    file = "tapr_campus_161920102_student.html"
  )
  dir.create(dirname(cp), recursive = TRUE)
  file.copy(fixture_path("tapr_student_report.html"), cp, overwrite = TRUE)
  write_sidecar(cp, list(
    source = "tapr", year = 2025L, school_year = "2024-25",
    level = "campus", geography = "161920102",
    data_type = "rates", file_format = "html",
    source_url = tapr_html_report_url(2025, "campus", "161920102"),
    retrieved_at = iso8601_now(), sha256 = sha256_file(cp),
    size_bytes = file.size(cp), content_type = "text/html"
  ))

  df <- txs_get_tapr_file(
    2025,
    level = "campus",
    geography = "161920102",
    data_type = "rates",
    file_format = "html",
    output = "raw",
    verbose = FALSE
  )
  meta <- attr(df, "txschools")

  expect_named(df, c("measure", "campus_count", "campus_percent", "district", "state"))
  expect_true(any(df$measure == "Total Students"))
  expect_true(any(df$campus_count == "*"))
  expect_equal(meta$year, 2025L)
  expect_equal(meta$school_year, "2024-25")
  expect_equal(meta$file_format, "html")
  expect_true(meta$used_cache)
})

test_that("txs_get_tapr returns semantic TAPR tables", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  cache_tapr_page_fixture(
    2025, "161920102", "student", "tapr_student_report.html",
    prgopt = "reports/tapr/student.sas"
  )
  cache_tapr_page_fixture(
    2025, "161920102", "staar_performance", "tapr_staar_performance.html",
    prgopt = "reports/tapr/perf_addsg.sas"
  )
  cache_tapr_page_fixture(
    2025, "161920102", "staar_progress", "tapr_staar_progress.html",
    prgopt = "reports/tapr/progress.sas"
  )

  x <- txs_get_tapr(
    year = 2025,
    level = "campus",
    geography = "161920102",
    datasets = c(
      "grade", "ethnic", "sex",
      "cohorts", "program", "disability",
      "mobility", "attrition", "retention", "class_size",
      "staar_performance", "staar_progress"
    ),
    verbose = FALSE
  )

  expect_s3_class(x, "tapr")
  expect_named(x, c(
    "grade", "ethnic", "sex",
    "cohorts", "program", "disability",
    "mobility", "attrition", "retention", "class_size",
    "staar_performance", "staar_progress"
  ))
  expect_true(all(c("Grade 2", "Grade 3", "Grade 4") %in% x$grade$grade))
  expect_true(all(c("Female", "Male") %in% x$sex$sex))
  expect_true("Economically Disadvantaged" %in% x$cohorts$cohort)
  expect_true("Special Education" %in% x$program$program)
  expect_true("Students with Intellectual Disabilities" %in%
                x$disability$disability)
  expect_true("Total Mobile Students" %in% x$mobility$mobility)
  expect_true("Total Student Attrition Rate" %in% x$attrition$attrition)
  expect_true("Grade 2 Retention" %in% x$retention$retention)
  expect_true("Grade 2 Average Class Size" %in% x$class_size$class_size)

  grade3 <- x$grade[x$grade$grade == "Grade 3", , drop = FALSE]
  expect_true(any(grade3$count_masked))
  expect_true(any(is.na(grade3$count[grade3$count_masked])))
  expect_type(x$grade$count, "integer")
  expect_equal(x$grade$campus_percent[x$grade$grade == "Grade 2"], 0.295)
  expect_equal(x$grade$district_percent[x$grade$grade == "Grade 2"], 0.06)
  expect_equal(x$grade$entity_name[[1]], "CHINA SPRING EL")
  expect_equal(x$grade$district_name[[1]], "CHINA SPRING ISD")
  expect_gt(nrow(x$staar_performance), 0)
  expect_false("value_num" %in% names(x$staar_performance))
  expect_gt(nrow(attr(x, "txschools")$pages), 0)
})

test_that("txs_get_tapr supports vectorized years and geographies", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  for (yr in c(2024, 2025)) {
    for (geo in c("161920102", "161920103")) {
      cache_tapr_page_fixture(
        yr, geo, "student", "tapr_student_report.html",
        prgopt = "reports/tapr/student.sas"
      )
    }
  }

  x <- txs_get_tapr(
    year = c(2024, 2025),
    level = "campus",
    geography = c("161920102", "161920103"),
    datasets = "sex",
    verbose = FALSE
  )

  expect_named(x, "sex")
  expect_setequal(x$sex$year, c(2024L, 2025L))
  expect_setequal(x$sex$geography, c("161920102", "161920103"))
  expect_equal(nrow(x$sex), 8L)
})

test_that("txs_get_tapr only returns requested dataset keys", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  cache_tapr_page_fixture(
    2025, "161920102", "student", "tapr_student_report.html",
    prgopt = "reports/tapr/student.sas"
  )

  x <- txs_get_tapr(
    year = 2025,
    level = "campus",
    geography = "161920102",
    datasets = c("grade", "sex"),
    verbose = FALSE
  )
  expect_named(x, c("grade", "sex"))
})

test_that("semantic TAPR page messages use readable labels", {
  expect_equal(tapr_page_message_label("student"), "student information")
  expect_equal(tapr_page_message_label("staar_performance"), "STAAR performance")
  expect_equal(tapr_page_message_label("bilingual_esl"), "bilingual/ESL")
})

test_that("txs_write_tapr_db writes semantic tables when DuckDB is available", {
  testthat::skip_if_not_installed("DBI")
  testthat::skip_if_not_installed("duckdb")

  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  cache_tapr_page_fixture(
    2025, "161920102", "student", "tapr_student_report.html",
    prgopt = "reports/tapr/student.sas"
  )

  x <- txs_get_tapr(
    year = 2025,
    level = "campus",
    geography = "161920102",
    datasets = c("grade", "sex"),
    verbose = FALSE
  )
  db <- tempfile(fileext = ".duckdb")
  txs_write_tapr_db(x, db = db, overwrite = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  expect_true(DBI::dbExistsTable(con, "grade"))
  expect_true(DBI::dbExistsTable(con, "_tapr_catalog"))
  expect_gt(nrow(DBI::dbReadTable(con, "grade")), 0)
})
