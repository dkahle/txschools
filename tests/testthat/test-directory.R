synthetic_ref <- function(level = "campus") {
  if (identical(level, "campus")) {
    tibble::tibble(
      CAMPUS   = c("'161920102", "'161920001", "'057905001"),
      CAMPNAME = c("CHINA SPRING EL", "CHINA SPRING H S", "SOME OTHER EL"),
      DISTRICT = c("'161920", "'161920", "'057905"),
      DISTNAME = c("CHINA SPRING ISD", "CHINA SPRING ISD", "OTHER ISD"),
      CNTYNAME = c("MCLENNAN", "MCLENNAN", "DALLAS"),
      REGION   = c("'12", "'12", "'10"),
      GRDSPAN  = c("'02 - 04", "'09 - 12", "'EE - 05")
    )
  } else {
    tibble::tibble(
      DISTRICT = c("'161920", "'057905"),
      DISTNAME = c("CHINA SPRING ISD", "OTHER ISD"),
      CNTYNAME = c("MCLENNAN", "DALLAS"),
      REGION   = c("'12", "'10")
    )
  }
}

test_that("directory_from_ref cleans identifiers and maps columns", {
  mockery::stub(directory_from_ref, "txs_get_tapr_file",
                function(year, level, ...) synthetic_ref(level))

  d <- directory_from_ref(2024, "campus", cache = TRUE, refresh = FALSE,
                          timeout = 60, verbose = FALSE)
  expect_equal(nrow(d), 3)
  expect_equal(d$id, c("161920102", "161920001", "057905001"))
  expect_equal(d$district[1], "161920")
  expect_equal(d$district_name[1], "CHINA SPRING ISD")
  expect_equal(d$region[1], "12")
  expect_equal(d$grade_span[1], "02 - 04")

  d2 <- directory_from_ref(2024, "district", cache = TRUE, refresh = FALSE,
                           timeout = 60, verbose = FALSE)
  expect_equal(d2$id, c("161920", "057905"))
  expect_equal(d2$name, d2$district_name)
})

test_that("txs_find_campus searches campus and district names", {
  mockery::stub(txs_find_campus, "txs_directory", function(year, level, ...) {
    mockery::stub(directory_from_ref, "txs_get_tapr_file",
                  function(year, level, ...) synthetic_ref(level))
    directory_from_ref(2024, "campus", cache = TRUE, refresh = FALSE,
                       timeout = 60, verbose = FALSE)
  })
  hits <- txs_find_campus("china spring")
  expect_equal(nrow(hits), 2)
  expect_true(all(grepl("^161920", hits$id)))
  expect_equal(nrow(txs_find_campus("no such school")), 0)
})

test_that("txs_find_district searches district names", {
  mockery::stub(txs_find_district, "txs_directory", function(year, level, ...) {
    mockery::stub(directory_from_ref, "txs_get_tapr_file",
                  function(year, level, ...) synthetic_ref(level))
    directory_from_ref(2024, "district", cache = TRUE, refresh = FALSE,
                       timeout = 60, verbose = FALSE)
  })
  hits <- txs_find_district("other")
  expect_equal(hits$id, "057905")
})

test_that("txs_directory falls back to earlier years when year=NULL", {
  calls <- integer(0)
  mockery::stub(txs_directory, "directory_from_ref",
                function(year, level, ...) {
                  calls <<- c(calls, year)
                  if (length(calls) < 2) stop("not published yet")
                  tibble::tibble(year = year, level = level,
                                 id = "161920102", name = "X",
                                 district = "161920", district_name = "Y",
                                 county_name = "Z", region = "12",
                                 grade_span = "EE - 05")
                })
  d <- txs_directory(level = "campus", verbose = FALSE)
  expect_equal(length(calls), 2)
  expect_gt(calls[1], calls[2])
  expect_equal(nrow(d), 1)
})
