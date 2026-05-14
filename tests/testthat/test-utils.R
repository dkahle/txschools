test_that("normalize_year accepts integer beginning years", {
  expect_identical(normalize_year(2023), 2023L)
  expect_identical(normalize_year(2024L), 2024L)
})

test_that("normalize_year rejects non-integer or out-of-range input", {
  expect_error(normalize_year("2023-24"), "integer like")
  expect_error(normalize_year(1999), "out of range")
  expect_error(normalize_year(2100), "out of range")
  expect_error(normalize_year(c(2022, 2023)), "single value")
})

test_that("year_label formats YYYY-YY", {
  expect_identical(year_label(2023), "2023-24")
  expect_identical(year_label(1999), "1999-00")
  expect_identical(year_label(2099), "2099-00")
})

test_that("year_from_label round-trips", {
  expect_identical(year_from_label("2023-24"), 2023L)
  expect_identical(year_from_label("2003-04"), 2003L)
})

test_that("ext_for_format maps correctly", {
  expect_identical(ext_for_format("csv"), "csv")
  expect_identical(ext_for_format("txt"), "dat")
  expect_identical(ext_for_format("xlsx"), "xlsx")
})
