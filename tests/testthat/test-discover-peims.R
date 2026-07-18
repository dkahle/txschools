test_that("peims_year_from_label handles both TEA label styles", {
  expect_equal(peims_year_from_label("1999-2000"), 2000L)
  expect_equal(peims_year_from_label("2015–2016"), 2016L)
  expect_equal(peims_year_from_label("2011-12"), 2012L)
  expect_equal(peims_year_from_label("2013–14"), 2014L)
  expect_true(is.na(peims_year_from_label("no year here")))
})

test_that("peims_classify_link classifies every basename era", {
  cases <- list(
    list(href = "/x/budget2024.zip",  level = "district", basis = "budget", year = 2024L),
    list(href = "/x/actget2013.zip",  level = "district", basis = "actual", year = 2013L),
    list(href = "/x/2017Budget.zip",  level = "district", basis = "budget", year = 2017L),
    list(href = "https://rptsvr1.tea.texas.gov/x/2005Actual.zip",
         level = "district", basis = "actual", year = 2005L),
    list(href = "/x/CharBud05.csv",   level = "charter",  basis = "budget", year = 2005L),
    list(href = "/x/charact19.zip",   level = "charter",  basis = "actual", year = 2019L)
  )
  for (cs in cases) {
    hit <- peims_classify_link(cs$href, "irrelevant text")
    expect_equal(hit$level, cs$level, info = cs$href)
    expect_equal(hit$data_type, cs$basis, info = cs$href)
    expect_equal(hit$year, cs$year, info = cs$href)
  }
  expect_null(peims_classify_link("/x/somepage.html", "About PEIMS"))
})

test_that("peims_classify_link falls back to descriptive link text", {
  hit <- peims_classify_link(
    "/WorkArea/linkit.aspx?LinkIdentifier=id&ItemID=25769820605",
    "District 2013–2014 Financial Actual Data (.zip 20,058 KB)"
  )
  expect_equal(hit$level, "district")
  expect_equal(hit$data_type, "actual")
  expect_equal(hit$year, 2014L)
})

test_that("parse_peims_index extracts rows across eras", {
  rows <- parse_peims_index(
    fixture_html("peims_index_page.html"), TXS_INDEX_PEIMS
  )
  df <- downloads_tibble(rows)
  expect_setequal(
    unique(df$year), c(2000L, 2005L, 2014L, 2024L, 2026L)
  )

  y2024 <- df[df$year == 2024, ]
  expect_equal(nrow(y2024), 4L)
  expect_setequal(paste(y2024$level, y2024$data_type),
                  c("district budget", "district actual",
                    "charter budget", "charter actual"))
  expect_true(all(startsWith(y2024$url, "https://tea.texas.gov/")))

  # WorkArea link classified from its text, URL kept opaque.
  wa <- df[df$year == 2014 & df$level == "district", ]
  expect_equal(wa$data_type, "actual")
  expect_match(wa$url, "WorkArea/linkit\\.aspx")

  # Old-era rptsvr1 basenames, including the 1999-2000 boundary.
  expect_equal(df$year[df$level == "district" &
                         grepl("2000Actual", df$url)], 2000L)

  filtered <- parse_peims_index(
    fixture_html("peims_index_page.html"), TXS_INDEX_PEIMS, year = 2005
  )
  expect_equal(length(filtered), 4L)
})

test_that("peims_fallback_rows covers the template and explicit eras", {
  cat <- catalog_source("peims")

  old <- downloads_tibble(peims_fallback_rows(2005L, cat))
  expect_equal(nrow(old), 4L)
  expect_true(all(grepl("rptsvr1\\.tea\\.texas\\.gov", old$url)))
  expect_true("https://rptsvr1.tea.texas.gov/school.finance/forecasting/downloads/Budget_Singlefile/CharBud05.csv" %in% old$url)

  new <- downloads_tibble(peims_fallback_rows(2024L, cat))
  expect_equal(nrow(new), 4L)
  expect_true(all(grepl("tea\\.texas\\.gov", new$url)))

  # Budget-only years yield budget-only rows.
  y2026 <- downloads_tibble(peims_fallback_rows(2026L, cat))
  expect_setequal(y2026$data_type, "budget")

  expect_length(peims_fallback_rows(1999L, cat), 0L)
})

test_that("txs_list_downloads('peims') caches discovery in _meta", {
  local_cache()
  mockery::stub(
    txs_list_downloads, "fetch_html",
    function(...) fixture_html("peims_index_page.html"),
    depth = 2
  )
  df <- txs_list_downloads(2024, "peims")
  expect_equal(nrow(df), 4L)
  expect_setequal(df$level, c("district", "charter"))

  meta_file <- file.path(txs_cache_dir(), "_meta", "downloads_peims_2024.yml")
  expect_true(file.exists(meta_file))

  # Second call must not need the network at all.
  mockery::stub(
    txs_list_downloads, "fetch_html",
    function(...) stop("network should not be touched"),
    depth = 2
  )
  df2 <- txs_list_downloads(2024, "peims")
  expect_equal(df2$url, df$url)
})

test_that("txs_list_years('peims') unions catalog and live years", {
  local_cache()
  mockery::stub(
    txs_list_years, "fetch_html",
    function(...) stop("offline"),
    depth = 3
  )
  yrs <- txs_list_years("peims")
  expect_true(all(2000:2026 %in% yrs$year))
  expect_equal(yrs$school_year[yrs$year == 2000], "1999-00")
})

test_that("parse_peims_codes_index finds the budget archive for a year", {
  html <- fixture_html("peims_codes_page.html")
  expect_equal(
    parse_peims_codes_index(html, TXS_INDEX_PEIMS_CODES, 2024),
    "https://tea.texas.gov/data-reports/financial-reports/school-finance-reports-and-data/budget2024d.zip"
  )
  expect_equal(
    parse_peims_codes_index(html, TXS_INDEX_PEIMS_CODES, 2005),
    "https://rptsvr1.tea.texas.gov/school.finance/forecasting/downloads/Budget_Multifile/Budget05.zip"
  )
  expect_true(is.na(parse_peims_codes_index(html, TXS_INDEX_PEIMS_CODES, 2019)))
})

test_that("discover_peims_codes_url falls back to the catalog offline", {
  mockery::stub(discover_peims_codes_url, "fetch_html",
                function(...) stop("offline"))
  expect_equal(
    discover_peims_codes_url(2018),
    "https://tea.texas.gov/sites/default/files/Budget18.zip"
  )
  expect_equal(
    discover_peims_codes_url(2005),
    "https://rptsvr1.tea.texas.gov/school.finance/forecasting/downloads/Budget_Multifile/Budget05.zip"
  )
})
