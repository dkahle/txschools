test_that("is_masked flags TEA codes and ignores numerics", {
  x <- c("12.3", "*", ".", " -1 ", "100", "n/a", "N/A", "0", NA_character_)
  expect_identical(
    is_masked(x),
    c(FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE)
  )
})

test_that("mask_strip never coerces masked values to numbers", {
  out <- mask_strip(c("12.3", "*", ".", "-1", "100"))
  expect_equal(out$value_num, c(12.3, NA, NA, NA, 100))
  expect_identical(out$masked, c(FALSE, TRUE, TRUE, TRUE, FALSE))
  expect_identical(out$mask_code, c(NA, "*", ".", "-1", NA))
})

test_that("mask_strip strips display formatting before parsing", {
  out <- mask_strip(c("97%", "$4,668", "1,234.5"))
  expect_equal(out$value_num, c(97, 4668, 1234.5))
  expect_false(any(out$masked))
})

test_that("mask_strip flags suppression-shaped markers instead of silent NA", {
  out <- mask_strip(c("< 1%", ">99%", "<5", "?", "--", "12.3"))
  expect_identical(out$masked, c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_identical(out$mask_code, c("< 1%", ">99%", "<5", "?", "--", NA))
  expect_equal(out$value_num, c(NA, NA, NA, NA, NA, 12.3))
})

test_that("mask_strip never mistakes year labels or spans for masks", {
  out <- mask_strip(c("2019-20", "02 - 04", "9-12"))
  expect_false(any(out$masked))
  expect_true(all(is.na(out$mask_code)))
  expect_true(all(is.na(out$value_num)))
})

test_that("mask_strip leaves ordinary text unmasked", {
  out <- mask_strip(c("MCLENNAN", "EE - 03", ""))
  expect_false(any(out$masked))
  expect_true(all(is.na(out$value_num)))
})

test_that("custom codes parameter is honored", {
  expect_true(is_masked("X", codes = "X"))
  expect_false(is_masked("X"))
})

test_that("options() override changes default codes", {
  withr::with_options(list(txschools.mask_values = c("Q")), {
    expect_true(is_masked("Q"))
    expect_false(is_masked("*"))
  })
})
