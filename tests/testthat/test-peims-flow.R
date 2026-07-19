# A small synthetic district: two funds, mixed sources, known totals.
peims_flow_fixture <- function(labels = TRUE) {
  x <- tibble::tibble(
    district = "161920",
    fund_code = c("199", "199", "199", "199", "199", "240", "240", "240",
                  "199", "199", "240"),
    fund_label = c(rep("GENERAL FUND", 5), rep("FOOD SERVICE", 3),
                   "GENERAL FUND", "GENERAL FUND", "FOOD SERVICE"),
    function_code = c("00", "00", "11", "51", "51", "00", "35", "35",
                      "00", "00", "00"),
    function_label = c("NO FUNCTION", "NO FUNCTION", "INSTRUCTION",
                       "FACILITY MAINTENANCE AND OPERATIONS",
                       "FACILITY MAINTENANCE AND OPERATIONS",
                       "NO FUNCTION", "FOOD SERVICES", "FOOD SERVICES",
                       "NO FUNCTION", "NO FUNCTION", "NO FUNCTION"),
    object_code = c("5711", "5811", "6119", "6249", "6634",
                    "5921", "6119", "6341",
                    "7911", "8911", "7915"),
    program_intent_code = "00",
    program_intent_label = "NO PROGRAM",
    amount = c(600, 300, 500, 200, 100, 120, 90, 60, 50, 20, 20),
    year = 2024L, school_year = "2023-24",
    basis = "actual", type = "district"
  )
  if (!labels) {
    x$fund_label <- NULL
    x$function_label <- NULL
    x$program_intent_label <- NULL
  }
  x
}

test_that("txs_peims_flow builds honest, balanced edges", {
  fl <- txs_peims_flow(peims_flow_fixture())
  expect_s3_class(fl, "peims_flow")
  expect_named(fl, c("from_axis", "from", "to_axis", "to", "amount"))
  expect_equal(attr(fl, "axes"), c("source", "fund", "function"))

  # Source -> fund edges match the revenue rows exactly.
  expect_equal(
    fl$amount[fl$from == "Local revenue" & fl$to == "General fund"], 600
  )
  expect_equal(
    fl$amount[fl$from == "Federal revenue" & fl$to == "Food service"], 120
  )

  # Transfers and other financing get their own half-edge nodes.
  expect_equal(
    fl$amount[fl$from == "Other financing sources" & fl$to == "General fund"],
    50
  )
  expect_equal(
    fl$amount[fl$from == "General fund" & fl$to == "Transfers to other funds"],
    20
  )
  expect_equal(
    fl$amount[fl$from == "Transfers from other funds" &
                fl$to == "Food service"], 20
  )

  # General fund: 950 in (900 revenue + 50 proceeds) vs 820 out
  # (800 spending + 20 transfer) -> 130 to fund balance.
  expect_equal(
    fl$amount[fl$from == "General fund" & fl$to == "To fund balance"], 130
  )
  # Food service: 140 in (120 revenue + 20 transfer) vs 150 spending
  # -> 10 from fund balance.
  expect_equal(
    fl$amount[fl$from == "From fund balance" & fl$to == "Food service"], 10
  )

  # Every fund's inflow equals its outflow.
  for (f in c("General fund", "Food service")) {
    expect_equal(sum(fl$amount[fl$to == f]), sum(fl$amount[fl$from == f]),
                 info = f)
  }
})

test_that("txs_peims_flow supports deeper spending axes", {
  fl <- txs_peims_flow(
    peims_flow_fixture(), axes = c("fund", "function", "object")
  )
  expect_setequal(unique(fl$from_axis), c("fund", "function"))
  # Instruction is all payroll (object 6119) in the fixture.
  expect_equal(
    fl$amount[fl$from == "Instruction" & fl$to == "Payroll"], 500
  )
  # No balancing, transfer, or financing nodes without a source axis.
  expect_false(any(grepl("fund balance|Transfers|financing",
                         c(fl$from, fl$to))))
})

test_that("txs_peims_flow lumps small nodes into Other", {
  fl <- txs_peims_flow(peims_flow_fixture(), lump = 1)
  funds <- unique(c(fl$to[fl$to_axis == "fund"], fl$from[fl$from_axis == "fund"]))
  expect_setequal(funds, c("General fund", "Other funds"))
})

test_that("txs_peims_flow falls back to codes without label columns", {
  fl <- txs_peims_flow(peims_flow_fixture(labels = FALSE))
  expect_true("Fund 199" %in% fl$to)
  expect_true("Function 11" %in% fl$to)
})

test_that("txs_peims_flow validates its axes", {
  x <- peims_flow_fixture()
  expect_error(txs_peims_flow(x, axes = c("source", "function")),
               "only be followed by")
  expect_error(txs_peims_flow(x, axes = c("function", "fund")),
               "canonical order")
  expect_error(txs_peims_flow(x, axes = "fund"), "two or more")
  expect_error(txs_peims_flow(tibble::tibble(a = 1)), "tidy output")
})

test_that("txs_plot_peims_flow returns a ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggsankey")
  p <- txs_plot_peims_flow(txs_peims_flow(peims_flow_fixture()), unit = 10)
  expect_s3_class(p, "ggplot")
  expect_error(txs_plot_peims_flow(tibble::tibble(a = 1)),
               "txs_peims_flow")
})
