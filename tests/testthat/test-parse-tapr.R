test_that("read_tapr_csv keeps everything as character and preserves masking", {
  df <- read_tapr_csv(fixture_path("synthetic_campus_advanced.csv"))
  expect_s3_class(df, "tbl_df")
  expect_true(all(vapply(df, is.character, logical(1))))

  # Mask codes must be preserved verbatim.
  expect_true("*"  %in% df$CA00AR01219R)
  expect_true("."  %in% df$CA00AR01219R)
  expect_true("-1" %in% df$CA00AR01219R)
})

test_that("read_tapr_file dispatches on extension", {
  df <- read_tapr_file(fixture_path("synthetic_campus_advanced.csv"))
  expect_equal(nrow(df), 5)
})
