# FIRST ratings come from two ASP.NET apps. The fake below serves the
# fixture pages and workbooks, answering each post by which control
# fired (__EVENTTARGET) or, for a Download click, by the posted URL.

first_html_resp <- function(fixture, url) {
  httr2::response(
    status_code = 200, url = url,
    headers = list(`Content-Type` = "text/html; charset=utf-8"),
    body = charToRaw(fixture_html(fixture))
  )
}

first_xlsx_resp <- function(fixture, url, filename) {
  path <- fixture_path(fixture)
  httr2::response(
    status_code = 200, url = url,
    headers = list(
      `Content-Type` = paste0("application/vnd.openxmlformats-",
                              "officedocument.spreadsheetml.sheet"),
      `Content-Disposition` = sprintf('attachment; filename="%s"', filename)
    ),
    body = readBin(path, "raw", file.size(path))
  )
}

first_fake_tea <- function(download = NULL) {
  calls <- list()
  record <- function(method, url, params = NULL, cookies = NULL) {
    calls[[length(calls) + 1L]] <<- list(method = method, url = url,
                                         params = params, cookies = cookies)
  }
  page_for <- function(url) {
    if (grepl("UniversityCharters=true", url, fixed = TRUE)) {
      "first_university_page_small.html"
    } else if (grepl("tealprod", url, fixed = TRUE)) {
      "first_school_page_small.html"
    } else {
      "first_charter_page_small.html"
    }
  }
  get <- function(url, timeout = NULL, max_tries = NULL, cookies = NULL) {
    record("get", url, cookies = cookies)
    first_html_resp(page_for(url), url)
  }
  post <- function(url, params, timeout = NULL, max_tries = NULL,
                   cookies = NULL) {
    record("post", url, params, cookies)
    target <- params[["__EVENTTARGET"]] %||% ""
    if (grepl("ddlNonAdmin$", target)) {
      # The real app answers with a 302 to the university view.
      to <- sub("District\\.aspx.*$", "District.aspx?UniversityCharters=true",
                url)
      return(first_html_resp("first_university_page_small.html", to))
    }
    if (nzchar(target)) return(first_html_resp(page_for(url), url))
    if (!is.null(download)) return(download(url))
    if (grepl("UniversityCharters=true", url, fixed = TRUE)) {
      first_xlsx_resp("first_university_charter_2026_small.xlsx", url,
                      "2026-Preliminary-University-CharterFIRST-Ratings.xlsx")
    } else if (grepl("tealprod", url, fixed = TRUE)) {
      first_xlsx_resp("first_school_2026_small.xlsx", url,
                      "2026-Final-FIRST-Ratings.xlsx")
    } else {
      first_xlsx_resp("first_charter_2026_small.xlsx", url,
                      "2026-Preliminary-CharterFIRST-Ratings.xlsx")
    }
  }
  list(get = get, post = post, calls = function() calls)
}

no_network <- function(...) stop("network should not be touched")

first_cols <- c("year", "school_year", "fiscal_year", "type",
                "university_charter", "district", "district_name", "region",
                "status", "rating", "grade", "score", "release",
                "last_updated")

test_that("aspnet_parse_form collects what a browser would submit", {
  form <- aspnet_parse_form(
    first_html_resp("first_school_page_small.html", TXS_URL_SCHOOL_FIRST)
  )
  expect_equal(form$action, TXS_URL_SCHOOL_FIRST)
  # Hidden input without a value attribute posts "".
  expect_equal(form$fields[["__LASTFOCUS"]], "")
  expect_equal(form$fields[["__VIEWSTATE"]], "dGVzdC12aWV3c3RhdGU=")
  # Selected option, else the first option.
  expect_equal(form$fields[["ctl00$AppBar$ddlYear"]], "2024")
  expect_equal(form$fields[["ctl00$AppBar$ddlDistrict"]], "")
  expect_equal(form$selects[["ctl00$AppBar$ddlYear"]]$label,
               c("2023-2024", "2024-2025", "2025-2026"))
  # Buttons are kept aside; the page carries no __EVENTTARGET.
  expect_setequal(names(form$buttons),
                  c("ctl00$AppBar$btnAppealSummary", "btnHelp",
                    "ctl00$Main$btnDownload"))
  expect_false(any(c("__EVENTTARGET", "btnHelp") %in% names(form$fields)))

  univ_url <- paste0(TXS_URL_CHARTER_FIRST, "?UniversityCharters=true")
  univ <- aspnet_parse_form(
    first_html_resp("first_university_page_small.html", univ_url)
  )
  expect_equal(univ$action, univ_url)
  expect_equal(univ$fields[["__VIEWSTATEENCRYPTED"]], "")
  expect_equal(univ$fields[["ctl00$ddlNonAdmin"]], "DistStatusUniversity")
})

test_that("postback and submit params mimic a browser", {
  form <- aspnet_parse_form(
    first_html_resp("first_school_page_small.html", TXS_URL_SCHOOL_FIRST)
  )
  pb <- aspnet_postback_params(form, "ctl00$AppBar$ddlYear", "2023")
  expect_equal(pb[["__EVENTTARGET"]], "ctl00$AppBar$ddlYear")
  expect_equal(pb[["__EVENTARGUMENT"]], "")
  expect_equal(pb[["ctl00$AppBar$ddlYear"]], "2023")
  expect_false(any(names(form$buttons) %in% names(pb)))

  sb <- aspnet_submit_params(form, "ctl00$Main$btnDownload")
  expect_equal(sb[["__EVENTTARGET"]], "")
  expect_equal(sb[["ctl00$Main$btnDownload"]], "Download")
  expect_false(any(c("btnHelp", "ctl00$AppBar$btnAppealSummary") %in%
                     names(sb)))

  expect_error(
    aspnet_find_control(names(form$selects), "[$]ddlNonAdmin$",
                        "list selector", "School FIRST"),
    "has 0 list selectors"
  )
})

test_that("years map to each app's option values by label", {
  school <- aspnet_parse_form(
    first_html_resp("first_school_page_small.html", TXS_URL_SCHOOL_FIRST)
  )
  charter <- aspnet_parse_form(
    first_html_resp("first_charter_page_small.html", TXS_URL_CHARTER_FIRST)
  )
  # Same 2025-26 ratings, different option values.
  expect_equal(first_option_value(school$selects[["ctl00$AppBar$ddlYear"]],
                                  2026L, "School FIRST"), "2024")
  expect_equal(first_option_value(charter$selects[["ctl00$ddlYear"]],
                                  2026L, "Charter FIRST"), "2025")
  expect_equal(first_option_value(charter$selects[["ctl00$ddlYear"]],
                                  2012L, "Charter FIRST"), "2011")
  expect_error(
    first_option_value(school$selects[["ctl00$AppBar$ddlYear"]], 2022L,
                       "School FIRST"),
    "available: 2023-24 to 2025-26",
    class = "txs_first_unavailable"
  )
})

test_that("FIRST workbooks parse and are checked before caching", {
  wb <- read_first_workbook(fixture_path("first_school_2026_small.xlsx"))
  expect_equal(wb$title, "2025-2026 FIRST Ratings — Final")
  expect_equal(nrow(wb$data), 3L)  # footer row dropped
  expect_equal(names(wb$data),
               c("District#", "District_Name", "Status", "Rating", "Score",
                 "Last Updated Date", "Region"))
  expect_silent(first_check_workbook(wb, "district", 2026L))
  expect_error(first_check_workbook(wb, "district", 2025L),
               "workbook for 2025-26, not 2024-25")
  expect_error(first_check_workbook(wb, "charter", 2026L),
               "different FIRST list")

  ch <- read_first_workbook(fixture_path("first_charter_2026_small.xlsx"))
  expect_silent(first_check_workbook(ch, "charter", 2026L))
  expect_error(first_check_workbook(ch, "university_charter", 2026L),
               "different FIRST list")

  un <- read_first_workbook(
    fixture_path("first_university_charter_2026_small.xlsx")
  )
  expect_silent(first_check_workbook(un, "university_charter", 2026L))
  expect_match(un$title, "Preliminary (University Charters)", fixed = TRUE)
})

test_that("read_first_workbook errors when TEA's layout changes", {
  testthat::local_mocked_bindings(
    read_excel = function(...) {
      tibble::tibble(a = c("2025-2026 FIRST Ratings", "District#"),
                     b = c(NA, "Rating"))
    },
    .package = "readxl"
  )
  expect_error(read_first_workbook("ignored.xlsx"),
               "layout changed; missing column")
})

test_that("first_tidy types and normalizes every era", {
  data <- tibble::tibble(
    `District#` = c("1902", "57905", "3801", "227806"),
    District_Name = c(" CAYUGA   ISD ", "DALLAS ISD",
                      "PINEYWOODS COMMUNITY ACADEMY", "UT CHARTER"),
    Status = c("Pass", "Fail", "Suspended", "Pass"),
    Rating = c("A = Superior", "Substandard Achievement ",
               "Suspended: No Reason Given", "Pass"),
    Score = c("100", "0", "", NA),
    `Last Updated Date` = c("46241.660173611112", "38208.6271296296", NA,
                            "46241"),
    Region = c("7", "10", NA, "13")
  )
  meta <- list(tea_title = "2002-2003 FIRST Ratings — Final",
               retrieved_at = "2026-10-19T00:00:00Z")
  x <- first_tidy(data, "district", 2003L, meta)
  expect_named(x, first_cols)
  expect_equal(x$district, c("001902", "057905", "003801", "227806"))
  expect_equal(x$region, c("07", "10", NA, "13"))
  expect_equal(x$district_name[1], "CAYUGA ISD")
  expect_equal(x$rating[2], "Substandard Achievement")
  expect_equal(x$grade, c("A", NA, NA, NA))
  expect_equal(x$score, c(100, 0, NA, NA))
  expect_equal(x$last_updated,
               as.Date(c("2026-08-07", "2004-08-09", NA, "2026-08-07")))
  expect_equal(unique(x$school_year), "2002-03")
  expect_equal(unique(x$fiscal_year), 2002L)
  expect_equal(unique(x$release), "final")

  expect_equal(
    first_grade(c("A - Superior Achievement", "C = Meets Standard",
                  "F = Substandard Achievement", "Above Standard Achievement",
                  NA)),
    c("A", "C", "F", NA, NA)
  )
  empty <- first_tidy(data[0, ], "charter", 2026L, meta)
  expect_equal(nrow(empty), 0L)
  expect_type(empty$district, "character")
})

test_that("release: TEA's label for charters, download date for districts", {
  prelim <- "2025-2026 CharterFIRST Ratings — Preliminary"
  final_charter <- "2025-2026 CharterFIRST Ratings — Final"
  final_school <- "2025-2026 FIRST Ratings — Final"
  expect_equal(first_release("charter", prelim, "2027-01-05T00:00:00Z", 2026L),
               "preliminary")
  expect_equal(first_release("charter", final_charter, "2026-11-20T00:00:00Z",
                             2026L), "final")
  expect_equal(first_release("university_charter", prelim,
                             "2026-09-01T00:00:00Z", 2026L), "preliminary")
  # School FIRST titles every workbook "Final": the download date decides.
  expect_equal(first_release("district", final_school,
                             "2026-09-01T00:00:00Z", 2026L), "preliminary")
  expect_equal(first_release("district", final_school,
                             "2026-11-30T23:59:59Z", 2026L), "preliminary")
  expect_equal(first_release("district", final_school,
                             "2026-12-01T00:00:00Z", 2026L), "final")
  expect_equal(first_release("district", "2002-2003 FIRST Ratings",
                             "2026-10-19T00:00:00Z", 2003L), "final")
})

test_that("a cached copy that predates final ratings prompts a refresh", {
  stale <- list(list = "charter", year = 2020L, used_cache = TRUE, meta = list(
    tea_title = "2019-2020 CharterFIRST Ratings — Preliminary",
    retrieved_at = "2020-09-01T00:00:00Z"
  ))
  expect_message(first_note_release(list(stale)), "refresh")
  final <- list(list = "district", year = 2003L, used_cache = TRUE, meta = list(
    tea_title = "2002-2003 FIRST Ratings — Final",
    retrieved_at = "2026-10-19T00:00:00Z"
  ))
  expect_silent(first_note_release(list(final)))
})

test_that("txs_get_first end to end, offline", {
  local_cache()
  tea <- first_fake_tea()
  testthat::local_mocked_bindings(http_get = tea$get,
                                  http_post_form = tea$post)
  x <- suppressMessages(txs_get_first(2026))

  expect_named(x, first_cols)
  expect_equal(nrow(x), 7L)  # 3 districts, 2 charters, 2 university
  expect_equal(sum(x$university_charter), 2L)
  expect_true(all(is.na(x$score[x$university_charter])))
  expect_setequal(x$type, c("district", "charter"))
  expect_true(all(c("001902", "161920", "057905", "003801", "014803",
                    "174801") %in% x$district))
  expect_false(is.unsorted(x$district))
  expect_equal(unique(x$release[x$type == "charter"]), "preliminary")
  expect_equal(unique(x$release[x$type == "district"]),
               first_release("district", "Final", iso8601_now(), 2026L))

  calls <- tea$calls()
  expect_equal(
    vapply(calls, `[[`, character(1), "method"),
    c("get", "post", "post",           # School FIRST
      "get", "post", "post",           # Charter FIRST
      "get", "post", "post", "post")   # university list: extra postback
  )
  target <- function(cl) cl$params[["__EVENTTARGET"]] %||% NA_character_
  # Each app gets its own option value for the 2025-26 ratings.
  year_posts <- Filter(function(cl) grepl("ddlYear$", target(cl)), calls)
  expect_equal(
    vapply(year_posts, function(cl) cl$params[[target(cl)]], character(1)),
    c("2024", "2025", "2025")
  )
  downloads <- Filter(function(cl) identical(target(cl), ""), calls)
  expect_length(downloads, 3L)
  expect_equal(downloads[[1]]$params[["ctl00$Main$btnDownload"]], "Download")
  expect_false("btnHelp" %in% names(downloads[[1]]$params))
  # The university Download goes to the redirected form action.
  expect_match(downloads[[3]]$url, "UniversityCharters=true", fixed = TRUE)
  # One cookie jar per session, shared within it.
  jars <- vapply(calls, `[[`, character(1), "cookies")
  expect_length(unique(jars), 3L)
  expect_length(unique(jars[1:3]), 1L)

  # Provenance: TEA's title and file name, never the viewstate.
  meta <- attr(x, "txschools")
  expect_equal(meta$source, "first")
  expect_length(meta$files, 3L)
  expect_equal(meta$files[[1]]$tea_filename, "2026-Final-FIRST-Ratings.xlsx")
  side <- readLines(sidecar_path(cache_path(
    "first", 2026, "district", "ratings", file = "first_district_2026.xlsx"
  )))
  expect_false(any(grepl("VIEWSTATE", side)))
  expect_true(any(grepl("^tea_title:", side)))
  expect_match(format(txs_cite(x)), "FIRST")

  # A second call is served from the cache.
  testthat::local_mocked_bindings(http_get = no_network,
                                  http_post_form = no_network)
  x2 <- suppressMessages(txs_get_first(2026))
  expect_equal(x2, x, ignore_attr = TRUE)
  inv <- txs_cache_list()
  expect_setequal(inv$level[inv$source == "first"],
                  c("district", "charter", "university_charter"))

  raw <- txs_get_first(2026, type = "district", output = "raw",
                       verbose = FALSE)
  expect_equal(names(raw)[1:4], c("year", "list", "tea_title", "District#"))
  expect_type(raw$Score, "character")
})

test_that("an HTML answer instead of a workbook caches nothing", {
  local_cache()
  tea <- first_fake_tea(download = function(url) {
    first_html_resp("first_school_page_small.html", url)
  })
  testthat::local_mocked_bindings(http_get = tea$get,
                                  http_post_form = tea$post)
  warned <- NULL
  expect_error(
    withCallingHandlers(
      suppressMessages(txs_get_first(2026, type = "district")),
      warning = function(w) {
        warned <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    ),
    "No FIRST ratings could be retrieved"
  )
  expect_match(warned, "web page instead")
  expect_length(list.files(txs_cache_dir(), recursive = TRUE), 0L)
  # Retried once, in a fresh session.
  methods <- vapply(tea$calls(), `[[`, character(1), "method")
  expect_equal(sum(methods == "get"), 2L)
})

test_that("a year TEA does not list is reported, not retried", {
  local_cache()
  tea <- first_fake_tea()
  testthat::local_mocked_bindings(http_get = tea$get,
                                  http_post_form = tea$post)
  warned <- NULL
  expect_error(
    withCallingHandlers(
      suppressMessages(txs_get_first(2023, type = "district")),
      warning = function(w) {
        warned <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    ),
    "No FIRST ratings"
  )
  expect_match(warned, "does not list 2022-23 ratings")
  expect_length(tea$calls(), 1L)
})

test_that("years outside a list's coverage make no requests", {
  local_cache()
  testthat::local_mocked_bindings(http_get = no_network,
                                  http_post_form = no_network)
  said <- character()
  expect_error(
    withCallingHandlers(
      txs_get_first(2005, type = "charter"),
      message = function(m) {
        said <<- c(said, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    "No FIRST ratings"
  )
  expect_true(any(grepl("begin with 2011-12", said)))
  expect_error(txs_get_first(), "`years` is required")
  expect_error(txs_get_first(2002), "out of range")
})
