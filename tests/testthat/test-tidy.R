test_that("to_tidy pivots, preserves mask codes, and separates value_num", {
  df <- read_tapr_csv(fixture_path("synthetic_campus_advanced.csv"))
  long <- to_tidy(df, year = 2024, level = "campus")

  expect_true(all(c("variable_code", "value", "value_num",
                    "masked", "mask_code") %in% names(long)))
  expect_true(any(long$value == "*"))
  expect_true(any(long$value == "."))
  expect_true(any(long$value == "-1"))

  # No masked value leaks into value_num.
  expect_true(all(is.na(long$value_num[long$masked])))
  # value_num is numeric where masked is FALSE and value parses.
  numeric_rows <- !long$masked & grepl("^-?\\d", long$value)
  expect_true(any(!is.na(long$value_num[numeric_rows])))
})

test_that("to_raw is a passthrough", {
  df <- read_tapr_csv(fixture_path("synthetic_campus_advanced.csv"))
  expect_identical(to_raw(df), df)
})

test_that("to_wide attaches labels attribute when codebook is present", {
  df <- read_tapr_csv(fixture_path("synthetic_campus_advanced.csv"))
  out <- to_wide(df, year = 2024, level = "campus")
  # Same data, but with a `labels` attribute populated from the
  # bundled codebook (entries for keys not in the codebook are NA).
  expect_equal(as.data.frame(out), as.data.frame(df), ignore_attr = TRUE)
  labs <- attr(out, "labels")
  expect_true(!is.null(labs))
  expect_identical(unname(labs[["CAMPUS"]]), "Campus number (TEA 9-digit)")
})
