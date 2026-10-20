test_that("http_request throttles strictly, without bursts", {
  withr::local_options(txschools.respect_robots = FALSE)
  http_request("https://throttle-test.example/x")
  # A one-token bucket: one request per 1 / rate seconds.
  st <- httr2::throttle_status()
  expect_equal(st$capacity[st$realm == "throttle-test.example"], 1)
})
