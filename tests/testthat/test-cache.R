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
  cp <- cache_path("tapr", 2024, "campus", "advanced", file = "campadv.zip")
  dir.create(dirname(cp), recursive = TRUE)
  writeLines("dummy", cp)
  meta <- list(
    source = "tapr", year = 2024, school_year = "2023-24",
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
  expect_equal(inv$year[1], 2024L)
  expect_equal(inv$level[1], "campus")
  expect_equal(inv$file[1], "campadv.zip")
})

test_that("cache_delete with ask=FALSE removes file and sidecar", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  cp <- cache_path("tapr", 2024, "campus", "advanced", file = "a.csv")
  dir.create(dirname(cp), recursive = TRUE)
  writeLines("data", cp)
  write_sidecar(cp, list(
    source = "tapr", year = 2024, level = "campus",
    data_type = "advanced", file_format = "csv",
    source_url = "u", retrieved_at = iso8601_now(),
    sha256 = sha256_file(cp), size_bytes = file.size(cp)
  ))

  expect_equal(nrow(txs_cache_list()), 1)
  invisible(txs_cache_delete(year = 2024, source = "tapr", ask = FALSE))
  expect_false(file.exists(cp))
  expect_false(file.exists(sidecar_path(cp)))
  expect_equal(nrow(txs_cache_list()), 0)
})

test_that("cache_delete(all=TRUE) removes metadata-only cache directories", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  meta_dir <- file.path(dir, "_meta")
  dir.create(meta_dir, recursive = TRUE)
  writeLines("source: tapr", file.path(meta_dir, "years_tapr.yml"))

  invisible(txs_cache_delete(all = TRUE, ask = FALSE))
  expect_false(dir.exists(dir))
})

test_that("temporary cache helper restores the configured cache", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)

  tmp <- with_temporary_cache_dir({
    active <- txs_cache_dir()
    dir.create(file.path(active, "_meta"), recursive = TRUE)
    writeLines("source: tapr", file.path(active, "_meta", "years_tapr.yml"))
    active
  })

  expect_equal(txs_cache_dir(), normalizePath(dir, winslash = "/", mustWork = FALSE))
  expect_false(dir.exists(tmp))
})

# Writes a dummy file plus sidecar under the active cache dir. `meta` should
# carry the fields txs_cache_list()/txs_cache_size() key off of (source,
# year, level, data_type, dataset, file_format, source_url, retrieved_at,
# size_bytes). Mirrors the seeding done inline above, factored out because
# the tests below need many small variations.
seed_cache_entry <- function(file, meta) {
  cp <- cache_path(meta$source, meta$year, meta$level, meta$data_type, file = file)
  dir.create(dirname(cp), recursive = TRUE, showWarnings = FALSE)
  writeLines("x", cp)
  write_sidecar(cp, meta)
  cp
}

test_that("cache_size returns zero on an empty cache", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  out <- txs_cache_size()
  expect_equal(out$n_files, 0L)
  expect_equal(out$size_bytes, 0)
  expect_type(out$size, "character")
})

test_that("cache_size totals bytes and respects source/year filters", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  seed_cache_entry("a.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    dataset = "REF", file_format = "csv", source_url = "u1",
    retrieved_at = iso8601_now(), size_bytes = 1000
  ))
  seed_cache_entry("b.csv", list(
    source = "tapr", year = 2023L, level = "district", data_type = "advanced",
    dataset = "STAAR1", file_format = "csv", source_url = "u2",
    retrieved_at = iso8601_now(), size_bytes = 2500
  ))
  seed_cache_entry("c.pdf", list(
    source = "src", year = 2024L, level = "campus", data_type = "rates",
    file_format = "pdf", source_url = "u3",
    retrieved_at = iso8601_now(), size_bytes = 500
  ))

  total <- txs_cache_size()
  expect_equal(total$n_files, 3L)
  expect_equal(total$size_bytes, 4000)

  tapr_only <- txs_cache_size(source = "tapr")
  expect_equal(tapr_only$n_files, 2L)
  expect_equal(tapr_only$size_bytes, 3500)

  y2024 <- txs_cache_size(year = 2024)
  expect_equal(y2024$n_files, 2L)
  expect_equal(y2024$size_bytes, 1500)
})

test_that("cache_size groups by a column, keeping missing values as their own bucket", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  seed_cache_entry("a.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    dataset = "REF", file_format = "csv", source_url = "u1",
    retrieved_at = iso8601_now(), size_bytes = 1000
  ))
  seed_cache_entry("b.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    file_format = "csv", source_url = "u2",
    retrieved_at = iso8601_now(), size_bytes = 500
  )) # no `dataset` field -> NA
  seed_cache_entry("c.pdf", list(
    source = "src", year = 2024L, level = "campus", data_type = "rates",
    file_format = "pdf", source_url = "u3",
    retrieved_at = iso8601_now(), size_bytes = 300
  ))

  by_source <- txs_cache_size(by = "source")
  expect_equal(sum(by_source$n_files), 3L)
  expect_equal(sum(by_source$size_bytes), 1800)
  expect_setequal(by_source$source, c("tapr", "src"))

  by_dataset <- txs_cache_size(source = "tapr", by = "dataset")
  expect_equal(nrow(by_dataset), 2L)
  expect_equal(sum(by_dataset$n_files), 2L)
  expect_true(any(is.na(by_dataset$dataset)))
  expect_equal(by_dataset$size_bytes[is.na(by_dataset$dataset)], 500)
})

test_that("cache_size errors on an unknown `by` value", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  expect_error(txs_cache_size(by = "bogus"))
})

test_that("cache_list output carries the txs_cache class and prints a summary header", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  seed_cache_entry("a.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    dataset = "STAAR1", file_format = "csv", source_url = "u1",
    retrieved_at = iso8601_now(), size_bytes = 1000
  ))
  inv <- txs_cache_list()
  expect_s3_class(inv, "txs_cache")
  expect_s3_class(inv, "tbl_df")
  expect_equal(inv$dataset[1], "STAAR1")

  out <- capture.output(print(inv))
  expect_match(out[1], "1 file")
  expect_true(any(grepl("tapr", out)))
})

test_that("cache_delete(older_than=) removes only stale entries", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  old_cp <- seed_cache_entry("old.csv", list(
    source = "tapr", year = 2020L, level = "campus", data_type = "advanced",
    file_format = "csv", source_url = "u1",
    retrieved_at = "2020-01-01T00:00:00Z", size_bytes = 100
  ))
  new_cp <- seed_cache_entry("new.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    file_format = "csv", source_url = "u2",
    retrieved_at = iso8601_now(), size_bytes = 100
  ))

  invisible(txs_cache_delete(older_than = 365, ask = FALSE))
  expect_false(file.exists(old_cp))
  expect_true(file.exists(new_cp))
})

test_that("cache_delete(older_than=) accepts Date and POSIXct cutoffs", {
  cutoffs <- list(Sys.Date() - 1, Sys.time() - 86400)
  for (cutoff in cutoffs) {
    dir <- withr::local_tempdir()
    withr::local_options(txschools.cache_dir = dir)
    old_cp <- seed_cache_entry("old.csv", list(
      source = "tapr", year = 2020L, level = "campus", data_type = "advanced",
      file_format = "csv", source_url = "u1",
      retrieved_at = "2020-01-01T00:00:00Z", size_bytes = 100
    ))
    invisible(txs_cache_delete(older_than = cutoff, ask = FALSE))
    expect_false(file.exists(old_cp))
  }
})

test_that("cache_delete(older_than=) rejects a string duration", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  expect_error(
    txs_cache_delete(older_than = "180 days", ask = FALSE),
    "Date.*POSIXct"
  )
})

test_that("cache_size(older_than=) previews stale bytes without deleting anything", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  old_cp <- seed_cache_entry("old.csv", list(
    source = "tapr", year = 2020L, level = "campus", data_type = "advanced",
    file_format = "csv", source_url = "u1",
    retrieved_at = "2020-01-01T00:00:00Z", size_bytes = 100
  ))
  new_cp <- seed_cache_entry("new.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    file_format = "csv", source_url = "u2",
    retrieved_at = iso8601_now(), size_bytes = 250
  ))

  stale <- txs_cache_size(older_than = 365)
  expect_equal(stale$n_files, 1L)
  expect_equal(stale$size_bytes, 100)
  expect_true(file.exists(old_cp))
  expect_true(file.exists(new_cp))
})

test_that("cache_size and cache_delete filter by data_type and dataset symmetrically", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  ref_cp <- seed_cache_entry("ref.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    dataset = "REF", file_format = "csv", source_url = "u1",
    retrieved_at = iso8601_now(), size_bytes = 1000
  ))
  staar_cp <- seed_cache_entry("staar1.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    dataset = "STAAR1", file_format = "csv", source_url = "u2",
    retrieved_at = iso8601_now(), size_bytes = 2000
  ))
  dict_cp <- seed_cache_entry("dict.xlsx", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "dictionary",
    file_format = "xlsx", source_url = "u3",
    retrieved_at = iso8601_now(), size_bytes = 300
  ))

  expect_equal(txs_cache_size(data_type = "dictionary")$n_files, 1L)
  # Dataset matching is case-insensitive and never matches NA datasets.
  expect_equal(txs_cache_size(dataset = "ref")$size_bytes, 1000)
  expect_equal(txs_cache_size(dataset = c("REF", "STAAR1"))$n_files, 2L)

  invisible(txs_cache_delete(dataset = "staar1", ask = FALSE))
  expect_true(file.exists(ref_cp))
  expect_false(file.exists(staar_cp))
  expect_true(file.exists(dict_cp))

  invisible(txs_cache_delete(data_type = "dictionary", ask = FALSE))
  expect_false(file.exists(dict_cp))
  expect_true(file.exists(ref_cp))
})

test_that("cache print header tolerates sidecars without timestamps", {
  dir <- withr::local_tempdir()
  withr::local_options(txschools.cache_dir = dir)
  seed_cache_entry("a.csv", list(
    source = "tapr", year = 2024L, level = "campus", data_type = "advanced",
    file_format = "csv", source_url = "u1", size_bytes = 100
  )) # no retrieved_at
  inv <- txs_cache_list()
  expect_no_warning(out <- capture.output(print(inv)))
  expect_match(out[1], "1 file")
  expect_false(any(grepl("retrieved:", out)))
})
