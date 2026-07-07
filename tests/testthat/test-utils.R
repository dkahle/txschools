test_that("normalize_year accepts integer ending years", {
  expect_identical(normalize_year(2024), 2024L)
  expect_identical(normalize_year(2024L), 2024L)
})

test_that("normalize_year rejects non-integer or out-of-range input", {
  expect_error(normalize_year("2023-24"), "integer like")
  expect_error(normalize_year(1999), "out of range")
  expect_error(normalize_year(2100), "out of range")
  expect_error(normalize_year(c(2022, 2023)), "single value")
})

test_that("normalize_year enforces per-source coverage", {
  expect_identical(normalize_year(2013, source = "tapr"), 2013L)
  expect_error(normalize_year(2012, source = "tapr"), "out of range")
  expect_identical(normalize_year(2004, source = "aeis"), 2004L)
  expect_identical(normalize_year(2012, source = "aeis"), 2012L)
  expect_error(normalize_year(2013, source = "aeis"), "out of range")
  expect_identical(normalize_year(2019, source = "src"), 2019L)
  expect_error(normalize_year(2020, source = "src"), "out of range")
})

test_that("year_label formats YYYY-YY", {
  expect_identical(year_label(2024), "2023-24")
  expect_identical(year_label(2000), "1999-00")
  expect_identical(year_label(2100), "2099-00")
})

test_that("year_from_label round-trips", {
  expect_identical(year_from_label("2023-24"), 2024L)
  expect_identical(year_from_label("2003-04"), 2004L)
  expect_identical(year_from_label("1999-00"), 2000L)
})
