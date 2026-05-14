#' List the years available from a TEA source
#'
#' For TAPR, scrapes the public TEA TAPR landing page; for AEIS,
#' scrapes the archive index; for SRC, attempts the archive index and
#' falls back to the bundled catalog.
#'
#' Results are cached per session under `txs_cache_dir()/_meta/`. Pass
#' `refresh = TRUE` to force a re-fetch.
#'
#' @param source One of `"tapr"`, `"src"`, `"aeis"`.
#' @param refresh If `TRUE`, ignore the on-disk meta cache and re-fetch.
#' @return A tibble with columns `source`, `year`, `school_year`.
#' @examples
#' \dontrun{
#' txs_list_years("tapr")
#' }
#' @export
txs_list_years <- function(source = c("tapr", "src", "aeis"),
                           refresh = FALSE) {
  source <- match.arg(source)
  meta_dir <- file.path(txs_cache_dir(), "_meta")
  meta_file <- file.path(meta_dir, sprintf("years_%s.yml", source))
  if (!refresh && file.exists(meta_file)) {
    cached <- yaml::read_yaml(meta_file)
    return(years_tibble(source, cached$years))
  }

  years <- switch(
    source,
    tapr = discover_tapr_years(),
    aeis = discover_aeis_years(),
    src  = discover_src_years()
  )
  dir.create(meta_dir, recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(
    list(source = source, retrieved_at = iso8601_now(), years = as.integer(years)),
    meta_file
  )
  years_tibble(source, years)
}

years_tibble <- function(source, years) {
  years <- sort(unique(as.integer(years)))
  tibble::tibble(
    source      = rep(source, length(years)),
    year        = years,
    school_year = vapply(years, year_label, character(1))
  )
}

# --- Per-source discovery ---------------------------------------------------

discover_tapr_years <- function() {
  catalog <- catalog_years("tapr")
  live <- tryCatch({
    resp <- http_get(TXS_LANDING_TAPR)
    html <- rvest::read_html(httr2::resp_body_string(resp))
    txt  <- rvest::html_text(rvest::html_elements(html, "a"))
    # Extract beginning year from labels like "2023-24" or "2023<U+2013>24"
    # (ASCII hyphen-minus or Unicode en dash, both used on TEA pages).
    m <- stringr::str_extract(txt, "\\b(20\\d{2})\\s*[\u2013-]\\s*\\d{2}\\b")
    yrs <- as.integer(stringr::str_extract(m, "20\\d{2}"))
    yrs <- yrs[!is.na(yrs)]
    yrs
  }, error = function(e) integer(0))
  sort(unique(c(catalog, live)))
}

discover_aeis_years <- function() {
  catalog <- catalog_years("aeis")
  live <- tryCatch({
    resp <- http_get(paste0(TXS_BASE_AEIS, "/"))
    html <- rvest::read_html(httr2::resp_body_string(resp))
    hrefs <- rvest::html_attr(rvest::html_elements(html, "a"), "href")
    m <- stringr::str_extract(hrefs, "20\\d{2}-\\d{2}")
    yrs <- as.integer(stringr::str_extract(m, "20\\d{2}"))
    yrs <- yrs[!is.na(yrs) &
                 yrs >= TXS_FIRST_AEIS_YEAR &
                 yrs <= TXS_LAST_AEIS_YEAR]
    yrs
  }, error = function(e) integer(0))
  sort(unique(c(catalog, live)))
}

discover_src_years <- function() {
  catalog <- catalog_years("src")
  live <- tryCatch({
    resp <- http_get(paste0(TXS_BASE_SRC, "/"))
    html <- rvest::read_html(httr2::resp_body_string(resp))
    hrefs <- rvest::html_attr(rvest::html_elements(html, "a"), "href")
    m <- stringr::str_extract(hrefs, "20\\d{2}-\\d{2}")
    yrs <- as.integer(stringr::str_extract(m, "20\\d{2}"))
    yrs <- yrs[!is.na(yrs)]
    yrs
  }, error = function(e) {
    cli::cli_alert_info(
      "SRC archive index not reachable; using bundled catalog."
    )
    integer(0)
  })
  sort(unique(c(catalog, live)))
}

#' List downloads for a given year and source
#'
#' Discovers data files published for a particular TEA program year by
#' parsing the public HTML download pages. For TAPR this means
#' following the year's index to its Basic and Advanced download pages.
#'
#' @param year Integer beginning year.
#' @param source One of `"tapr"`, `"src"`, `"aeis"`.
#' @param refresh If `TRUE`, ignore the on-disk meta cache and re-fetch.
#' @return A tibble with columns `source`, `year`, `school_year`,
#'   `level`, `data_type`, `file_format`, `label`, `url`.
#' @examples
#' \dontrun{
#' txs_list_downloads(2023, "tapr")
#' }
#' @export
txs_list_downloads <- function(year,
                               source = c("tapr", "src", "aeis"),
                               refresh = FALSE) {
  year <- normalize_year(year)
  source <- match.arg(source)
  meta_dir <- file.path(txs_cache_dir(), "_meta")
  meta_file <- file.path(
    meta_dir,
    sprintf("downloads_%s_%d.yml", source, year)
  )
  if (!refresh && file.exists(meta_file)) {
    cached <- yaml::read_yaml(meta_file)
    if (length(cached$rows)) {
      return(downloads_tibble(cached$rows))
    }
  }

  rows <- switch(
    source,
    tapr = discover_tapr_downloads(year),
    aeis = discover_aeis_downloads(year),
    src  = discover_src_downloads(year)
  )
  dir.create(meta_dir, recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(
    list(source = source, year = year, retrieved_at = iso8601_now(),
         rows = rows),
    meta_file
  )
  downloads_tibble(rows)
}

downloads_tibble <- function(rows) {
  if (!length(rows)) {
    return(tibble::tibble(
      source = character(), year = integer(), school_year = character(),
      level = character(), data_type = character(),
      file_format = character(), label = character(), url = character()
    ))
  }
  do.call(rbind, lapply(rows, function(r) {
    tibble::tibble(
      source      = r$source      %||% NA_character_,
      year        = as.integer(r$year %||% NA_integer_),
      school_year = r$school_year %||% NA_character_,
      level       = r$level       %||% NA_character_,
      data_type   = r$data_type   %||% NA_character_,
      file_format = r$file_format %||% NA_character_,
      label       = r$label       %||% NA_character_,
      url         = r$url         %||% NA_character_
    )
  }))
}

# --- TAPR ------------------------------------------------------------------

discover_tapr_downloads <- function(year) {
  rows <- list()
  # 1. Live HTML
  live <- tryCatch(
    scrape_tapr_download_pages(year),
    error = function(e) list()
  )
  rows <- c(rows, live)

  # 2. Catalog fallback specific to the year
  cat <- catalog_source("tapr")
  fallback_key <- sprintf("files_%d", year)
  if (!length(rows) && !is.null(cat[[fallback_key]])) {
    rows <- lapply(cat[[fallback_key]], function(r) {
      r$source      <- "tapr"
      r$year        <- year
      r$school_year <- year_label(year)
      r$url         <- catalog_url(r$url, cat$base, year)
      r
    })
  }
  unique_rows(rows)
}

scrape_tapr_download_pages <- function(year) {
  cat   <- catalog_source("tapr")
  base  <- cat$base
  pages <- list(
    rates    = catalog_url(cat$basic_download,    base, year),
    advanced = catalog_url(cat$advanced_download, base, year)
  )
  out <- list()
  for (page_kind in names(pages)) {
    page_url <- pages[[page_kind]]
    rows <- tryCatch(
      extract_links_from_page(page_url, year = year, source = "tapr",
                              data_type = page_kind, level_prefixes = cat$level_prefixes),
      error = function(e) list()
    )
    out <- c(out, rows)
  }
  out
}

# Walk the <a> elements on a TEA download page, keep only file-like
# hrefs, and classify each by level/data_type/file_format.
extract_links_from_page <- function(page_url, year, source, data_type,
                                    level_prefixes) {
  html_str <- fetch_html(page_url)
  parse_links_html(html_str, page_url = page_url, year = year,
                   source = source, data_type = data_type,
                   level_prefixes = level_prefixes)
}

# Thin fetch wrapper so tests can stub just the network half.
fetch_html <- function(page_url) {
  resp <- http_get(page_url)
  httr2::resp_body_string(resp)
}

# Pure-function HTML parser; no network calls. Easy to test against
# fixture strings.
parse_links_html <- function(html_str, page_url, year, source, data_type,
                             level_prefixes) {
  html <- rvest::read_html(html_str)
  anchors <- rvest::html_elements(html, "a")
  hrefs <- rvest::html_attr(anchors, "href")
  labels <- trimws(rvest::html_text(anchors))
  keep <- grepl(
    "\\.(csv|txt|dat|xls|xlsx|zip)(\\?|$)",
    hrefs, ignore.case = TRUE
  )
  hrefs <- hrefs[keep]; labels <- labels[keep]
  if (!length(hrefs)) return(list())
  urls <- vapply(hrefs, function(h) xml2::url_absolute(h, page_url),
                 character(1))
  rows <- list()
  for (i in seq_along(urls)) {
    bn  <- tolower(basename(httr2::url_parse(urls[i])$path))
    lvl <- classify_level(bn, level_prefixes)
    fmt <- classify_format(bn)
    if (is.na(lvl) || is.na(fmt)) next
    rows[[length(rows) + 1L]] <- list(
      source      = source,
      year        = year,
      school_year = year_label(year),
      level       = lvl,
      data_type   = data_type,
      file_format = fmt,
      label       = labels[i],
      url         = urls[i]
    )
  }
  rows
}

classify_level <- function(filename, prefixes) {
  if (is.null(prefixes)) prefixes <- list(
    campus = c("cs", "camp", "ca"),
    district = c("dis", "dist", "dt"),
    region = c("reg"),
    state = c("state", "st")
  )
  bn <- tolower(filename)
  for (lvl in names(prefixes)) {
    for (px in prefixes[[lvl]]) {
      if (startsWith(bn, px)) return(lvl)
    }
  }
  NA_character_
}

classify_format <- function(filename) {
  ext <- tolower(tools::file_ext(filename))
  switch(
    ext,
    csv  = "csv",
    txt  = "txt",
    dat  = "txt",
    xls  = "xlsx",
    xlsx = "xlsx",
    zip  = "csv",   # TEA serves grouped CSVs inside zips
    NA_character_
  )
}

unique_rows <- function(rows) {
  if (!length(rows)) return(rows)
  key <- vapply(rows, function(r) paste(r$level, r$data_type, r$file_format, r$url),
                character(1))
  rows[!duplicated(key)]
}

# --- AEIS / SRC ------------------------------------------------------------

discover_aeis_downloads <- function(year) {
  cat  <- catalog_source("aeis")
  base <- cat$base
  landing <- catalog_url(cat$landing, base, year)
  tryCatch(
    extract_links_from_page(landing, year = year, source = "aeis",
                            data_type = "rates",
                            level_prefixes = cat$level_prefixes),
    error = function(e) list()
  )
}

discover_src_downloads <- function(year) {
  cat  <- catalog_source("src")
  base <- cat$base
  landing <- catalog_url(cat$landing, base, year)
  tryCatch(
    extract_links_from_page(landing, year = year, source = "src",
                            data_type = "rates",
                            level_prefixes = cat$level_prefixes),
    error = function(e) list()
  )
}
