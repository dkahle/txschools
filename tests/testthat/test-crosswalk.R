crosswalk_fake_pages <- function() {
  list(
    "page1" = list(
      results = data.frame(
        leaid = c("4816860", "4819910"),
        state_leaid = c("TX-057905", "TX-161920"),
        lea_name = c("DALLAS ISD", "CHINA SPRING ISD")
      ),
      "next" = "page2"
    ),
    "page2" = list(
      results = data.frame(
        leaid = c("4800001", "4800002"),
        state_leaid = c("TX-054901", "BAD"),
        lea_name = c("CROSBYTON CISD", "JUNK ROW")
      ),
      "next" = NULL
    )
  )
}

test_that("txs_crosswalk paginates, derives ids, and caches", {
  local_cache()
  pages <- crosswalk_fake_pages()
  testthat::local_mocked_bindings(
    crosswalk_fetch_page = function(url, ...) {
      if (grepl("educationdata", url)) pages$page1 else pages[[url]]
    }
  )

  x <- txs_crosswalk(verbose = FALSE)
  expect_named(x, c("geoid", "district", "lea_name"))
  # Both pages consumed; the row without a 6-digit CDN dropped.
  expect_equal(nrow(x), 3L)
  expect_equal(x$geoid[x$district == "161920"], "4819910")
  expect_equal(x$district[x$lea_name == "CROSBYTON CISD"], "054901")
  expect_equal(attr(x, "txschools")$source, "crosswalk")

  # Second call reads the cached CSV, no API.
  testthat::local_mocked_bindings(
    crosswalk_fetch_page = function(...) stop("no network")
  )
  x2 <- txs_crosswalk(verbose = FALSE)
  expect_equal(x2$geoid, x$geoid)
  expect_equal(x2$district, x$district)

  inv <- txs_cache_list()
  expect_true("crosswalk" %in% inv$source)
})
