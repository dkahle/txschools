test_that("http_request throttles strictly and takes an optional cookie jar", {
  withr::local_options(txschools.respect_robots = FALSE)
  req <- http_request("https://throttle-test.example/x")
  expect_null(req$options$cookiejar)
  # A one-token bucket: one request per 1 / rate seconds, no bursts.
  st <- httr2::throttle_status()
  expect_equal(st$capacity[st$realm == "throttle-test.example"], 1)

  jar <- withr::local_tempfile()
  req <- http_request("https://throttle-test.example/x", cookies = jar)
  expect_equal(req$options$cookiejar, jar)
  expect_equal(req$options$cookiefile, jar)
})

test_that("http_post_form posts a form body without forcing the method", {
  withr::local_options(txschools.respect_robots = FALSE)
  seen <- NULL
  httr2::local_mocked_responses(function(req) {
    seen <<- req
    httr2::response(200)
  })
  http_post_form("https://example.org/form",
                 list(`ctl00$ddlYear` = "2025",
                      `__EVENTTARGET` = "ctl00$ddlYear"))
  # No explicit method, so a 302 answer is followed as a GET.
  expect_null(seen$method)
  expect_equal(seen$body$type, "form")
  # httr2 stores form values already URL-encoded.
  sent <- function(name) utils::URLdecode(unclass(seen$body$data[[name]]))
  expect_equal(sent("ctl00$ddlYear"), "2025")
  expect_equal(sent("__EVENTTARGET"), "ctl00$ddlYear")
})
