test_that("txs_cite returns a generic bibentry per source", {
  e <- txs_cite(source = "tapr")
  expect_s3_class(e, "bibentry")
  expect_match(format(e), "Texas Academic Performance Reports")
})

test_that("txs_cite uses dataset metadata when available", {
  df <- tibble::tibble(x = 1)
  attr(df, "txschools") <- list(
    source = "tapr", year = 2023L, school_year = "2023-24",
    level = "campus", data_type = "advanced", file_format = "csv",
    source_url = "https://example.org/x.csv",
    retrieved_at = "2026-01-15T12:00:00Z",
    sha256 = strrep("a", 64), size_bytes = 100,
    cache_path = tempfile()
  )
  e <- txs_cite(df)
  expect_match(format(e), "TAPR 2023-24")
  expect_match(format(e), "2026-01-15T12:00:00Z")
  expect_match(format(e), "aaaaaaaaaaaa")
})
