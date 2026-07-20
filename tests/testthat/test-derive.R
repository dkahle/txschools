# Ports of txschoolviewer/tests/smoke.R math assertions.

test_that("txs_derive_pennies implements the HB3 decomposition", {
  df <- tibble::tibble(
    mcr = c(0.80, 0.80, 0.80, NA),
    mo_rate = c(0.80, 0.90, 0.95, 0.90),
    is_rate = c(0.10, NA, 0.20, 0.10)
  )
  out <- txs_derive_pennies(df)
  # mo - mcr = 0, .10 (capped at 8 golden + 2 copper), .15 (8 + 7).
  expect_equal(out$golden_pennies, c(0, 8, 8, NA))
  expect_equal(out$copper_pennies, c(0, 2, 7, NA))
  expect_equal(out$tier_one_rate, df$mcr)
  expect_equal(out$golden_rate[2], 0.08)
  expect_equal(out$copper_rate[3], 0.95 - 0.80 - 0.08)
  expect_equal(out$enrichment_rate[3], 0.15)
  # total = mo + coalesce(is, 0) when absent from input.
  expect_equal(out$total_rate, c(0.90, 0.90, 1.15, 1.00))
})

test_that("txs_derive_pennies respects existing total_rate and golden_cap", {
  df <- tibble::tibble(mcr = 0.8, mo_rate = 0.95, is_rate = 0.1,
                       total_rate = 99)
  expect_equal(txs_derive_pennies(df)$total_rate, 99)
  out <- txs_derive_pennies(dplyr::select(df, -total_rate),
                            golden_cap = 0.05)
  expect_equal(out$golden_pennies, 5)
  expect_equal(out$copper_pennies, 10)
})

test_that("txs_derive_pennies errors clearly on missing columns", {
  expect_error(txs_derive_pennies(tibble::tibble(mo_rate = 1)), "mcr")
})

test_that("txs_homestead_exemption schedule (keyed on ending year)", {
  # Ending year -> tax year = ending - 1.
  expect_equal(txs_homestead_exemption(2015), 15000)   # tax 2014
  expect_equal(txs_homestead_exemption(2016), 25000)   # tax 2015
  expect_equal(txs_homestead_exemption(2022), 25000)   # tax 2021
  expect_equal(txs_homestead_exemption(2023), 40000)   # tax 2022
  expect_equal(txs_homestead_exemption(2024), 100000)  # tax 2023
  expect_equal(txs_homestead_exemption(2025), 100000)  # tax 2024
  expect_equal(txs_homestead_exemption(2026), 140000)  # tax 2025
  expect_equal(txs_homestead_exemption(c(2015, 2026)), c(15000, 140000))
})
