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
