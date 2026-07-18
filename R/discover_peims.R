# PEIMS financial data discovery.
#
# TEA publishes the PEIMS "single file" financial downloads as direct
# file links on one index page. Hosts and paths vary by era (rptsvr1
# through 2011, several tea.texas.gov paths after), but the file
# basenames follow a stable grammar, and links whose URL is opaque
# (Ektron /WorkArea/ redirects) carry a fully descriptive link text.
# Live scraping of the index is authoritative; the bundled catalog holds
# fallback URLs verified at authoring time.

discover_peims_years <- function() {
  catalog <- catalog_years("peims")
  live <- tryCatch({
    html_str <- fetch_html(TXS_INDEX_PEIMS)
    rows <- parse_peims_index(html_str, TXS_INDEX_PEIMS)
    vapply(rows, function(r) as.integer(r$year), integer(1))
  }, error = function(e) integer(0))
  sort(unique(c(catalog, live)))
}

discover_peims_downloads <- function(year) {
  rows <- tryCatch({
    html_str <- fetch_html(TXS_INDEX_PEIMS)
    parse_peims_index(html_str, TXS_INDEX_PEIMS, year = year)
  }, error = function(e) list())
  if (!length(rows)) {
    rows <- peims_fallback_rows(year, catalog_source("peims"))
  }
  rows
}

# Parse the single-file index page into standard download rows. Pure
# function over the page HTML; `year = NULL` returns rows for all years.
parse_peims_index <- function(html_str, page_url, year = NULL) {
  html <- read_html_tolerant(html_str)
  anchors <- rvest::html_elements(html, "a")
  hrefs <- rvest::html_attr(anchors, "href")
  texts <- rvest::html_text(anchors)

  rows <- list()
  for (i in seq_along(hrefs)) {
    href <- hrefs[i]
    if (is.na(href) || !nzchar(href)) next
    hit <- peims_classify_link(href, texts[i])
    if (is.null(hit)) next
    url <- xml2::url_absolute(href, page_url)
    rows[[length(rows) + 1L]] <- list(
      source      = "peims",
      year        = hit$year,
      school_year = year_label(hit$year),
      level       = hit$level,
      data_type   = hit$data_type,
      dataset     = NA_character_,
      file_format = hit$file_format,
      label       = peims_clean_text(texts[i]),
      method      = "get",
      url         = url,
      params      = NA_character_
    )
  }
  rows <- unique_rows(rows)
  if (!is.null(year)) {
    rows <- Filter(function(r) identical(as.integer(r$year), as.integer(year)),
                   rows)
  }
  rows
}

# Classify one link into list(level, data_type, year, file_format), or
# NULL if it is not a PEIMS single-file download. Basenames are tried
# first; links with opaque URLs (WorkArea redirects, descriptive Drupal
# slugs) fall back to their link text, which TEA writes as
# "District 2013-2014 Financial Actual Data (.zip 20,058 KB)".
peims_classify_link <- function(href, text) {
  bn <- tolower(basename(sub("[?#].*$", "", href)))

  patterns <- list(
    list(re = "^budget(\\d{4})\\.zip$",         level = "district", data_type = "budget"),
    list(re = "^actget(\\d{4})\\.zip$",         level = "district", data_type = "actual"),
    list(re = "^(\\d{4})budget\\.zip$",         level = "district", data_type = "budget"),
    list(re = "^(\\d{4})actual\\.zip$",         level = "district", data_type = "actual"),
    list(re = "^charbud(\\d{2})\\.(zip|csv)$",  level = "charter",  data_type = "budget"),
    list(re = "^charact(\\d{2})\\.(zip|csv)$",  level = "charter",  data_type = "actual")
  )
  for (p in patterns) {
    m <- regmatches(bn, regexec(p$re, bn))[[1]]
    if (length(m)) {
      digits <- m[2]
      yr <- if (nchar(digits) == 4L) as.integer(digits) else 2000L + as.integer(digits)
      return(list(level = p$level, data_type = p$data_type, year = yr,
                  file_format = classify_format(bn)))
    }
  }

  txt <- tolower(peims_clean_text(text))
  m <- regmatches(
    txt,
    regexec(paste0(
      "^(district|charter)\\s+(\\d{4}\\s*[\u2013-]\\s*\\d{2,4})\\s+",
      "financial\\s+(budget|actual)\\s+data"
    ), txt)
  )[[1]]
  if (length(m) == 4L) {
    yr <- peims_year_from_label(m[3])
    if (is.na(yr)) return(NULL)
    # Both the bare CSVs and the zipped files parse as CSV data.
    return(list(level = m[2], data_type = m[4], year = yr, file_format = "csv"))
  }
  NULL
}

# Collapse whitespace (including non-breaking spaces) in link text.
peims_clean_text <- function(x) {
  x <- gsub("[\\s\u00a0]+", " ", x %||% "", perl = TRUE)
  trimws(x)
}

# Ending year of a school-year label. TEA's PEIMS pages mix
# "2015-2016" (two 4-digit years) with "2011-12"; year_from_label()
# only understands the latter.
peims_year_from_label <- function(x) {
  m <- regmatches(x, regexec("(\\d{4})\\s*[\u2013-]\\s*(\\d{4})", x))[[1]]
  if (length(m) == 3L) return(as.integer(m[3]))
  year_from_label(x)
}

peims_fallback_rows <- function(year, cat) {
  urls <- cat$files[[as.character(year)]] %||% list()
  if (!length(urls)) {
    for (tpl in cat$templates %||% list()) {
      rng <- range(as.integer(unlist(tpl$years)))
      if (year >= rng[1] && year <= rng[2]) {
        urls <- lapply(
          tpl[setdiff(names(tpl), "years")],
          function(u) catalog_url(u, cat$base %||% "", year)
        )
        break
      }
    }
  }

  rows <- list()
  for (key in names(urls)) {
    parts <- strsplit(key, "_", fixed = TRUE)[[1]]
    if (length(parts) != 2L) next
    rows[[length(rows) + 1L]] <- list(
      source      = "peims",
      year        = year,
      school_year = year_label(year),
      level       = parts[1],
      data_type   = parts[2],
      dataset     = NA_character_,
      file_format = classify_format(basename(urls[[key]])) %||% "csv",
      label       = sprintf("PEIMS %s %s financial %s data", parts[1],
                            year_label(year), parts[2]),
      method      = "get",
      url         = urls[[key]],
      params      = NA_character_
    )
  }
  rows
}

# URL of the budget "multiple file" archive whose code tables label a
# given year's data. Live scrape of the multiple-file index first, then
# the catalog. Returns NA_character_ when no source is known.
discover_peims_codes_url <- function(year) {
  live <- tryCatch({
    html_str <- fetch_html(TXS_INDEX_PEIMS_CODES)
    parse_peims_codes_index(html_str, TXS_INDEX_PEIMS_CODES, year)
  }, error = function(e) NA_character_)
  if (!is.na(live)) return(live)

  cat <- catalog_source("peims")
  url <- cat$codes_files[[as.character(year)]]
  if (length(url)) return(url)
  for (tpl in cat$codes_templates %||% list()) {
    rng <- range(as.integer(unlist(tpl$years)))
    if (year >= rng[1] && year <= rng[2]) {
      return(catalog_url(tpl$budget, cat$base %||% "", year))
    }
  }
  NA_character_
}

# The multiple-file index labels every link
# "1999-2000 Financial Budget Data (.zip 5,326 KB)"; the budget archive
# for the requested ending year carries that year's code tables.
parse_peims_codes_index <- function(html_str, page_url, year) {
  html <- read_html_tolerant(html_str)
  anchors <- rvest::html_elements(html, "a")
  hrefs <- rvest::html_attr(anchors, "href")
  texts <- vapply(rvest::html_text(anchors), peims_clean_text, character(1))

  for (i in seq_along(hrefs)) {
    if (is.na(hrefs[i]) || !nzchar(hrefs[i])) next
    txt <- tolower(texts[i])
    m <- regmatches(
      txt,
      regexec("^(\\d{4}\\s*[\u2013-]\\s*\\d{2,4})\\s+financial\\s+budget\\s+data", txt)
    )[[1]]
    if (length(m) != 2L) next
    if (identical(peims_year_from_label(m[2]), as.integer(year))) {
      return(xml2::url_absolute(hrefs[i], page_url))
    }
  }
  NA_character_
}
