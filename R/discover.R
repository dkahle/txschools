#' List the years available from a TEA source
#'
#' For TAPR, scrapes the public TEA TAPR landing page; for AEIS and SRC,
#' returns the archive years documented in the bundled catalog (verified
#' against TEA's site), augmented by live scraping where possible.
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

# --- Per-source year discovery ----------------------------------------------

discover_tapr_years <- function() {
  catalog <- catalog_years("tapr")
  live <- tryCatch({
    resp <- http_get(TXS_LANDING_TAPR)
    html <- rvest::read_html(httr2::resp_body_string(resp))
    txt  <- rvest::html_text(rvest::html_elements(html, "a"))
    # Extract ending year from labels like "2023-24" or "2023<U+2013>24"
    # (ASCII hyphen-minus or Unicode en dash, both used on TEA pages).
    m <- stringr::str_extract(txt, "\\b(20\\d{2})\\s*[\u2013-]\\s*\\d{2}\\b")
    yrs <- vapply(m[!is.na(m)], year_from_label, integer(1))
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
    txt <- rvest::html_text(rvest::html_elements(html, "a"))
    labels <- stringr::str_extract(txt, "\\b20\\d{2}\\s*[\u2013-]\\s*\\d{2}\\b")
    href_years <- stringr::str_extract(hrefs, "(?<!\\d)20\\d{2}(?!\\d)")
    yrs <- c(
      vapply(labels[!is.na(labels)], year_from_label, integer(1)),
      as.integer(href_years)
    )
    yrs <- yrs[!is.na(yrs) &
                 yrs >= TXS_FIRST_AEIS_YEAR &
                 yrs <= TXS_LAST_AEIS_YEAR]
    yrs
  }, error = function(e) integer(0))
  sort(unique(c(catalog, live)))
}

discover_src_years <- function() {
  # SRC has no live year index on rptsvr1 (the index page is a redirect
  # stub); the bundled catalog documents the verified report years.
  cat <- catalog_source("src")
  sort(unique(as.integer(c(cat$years_html, cat$years_pdf))))
}

#' List downloads for a given year and source
#'
#' Discovers data artifacts published for a particular TEA program year
#' by parsing the public HTML download pages, including the SAS-broker
#' download forms that serve the actual data files.
#'
#' For TAPR this returns:
#' * `data_type = "advanced"`: one row per level and dataset code
#'   (`dataset`, e.g. `"REF"`, `"STAAR1"`) served by TEA's SAS broker.
#'   These are the statewide data files (numerators, denominators, and
#'   rates).
#' * `data_type = "dictionary"`: the statewide variable-dictionary
#'   workbooks (`TAPR_campus_2024.xlsx`, ...). These describe variables;
#'   they do not contain data.
#'
#' For AEIS this returns one row per level and dataset code served by
#' the per-year AEIS CGI. SRC is not a downloadable-file program; see
#' [txs_get_src()].
#'
#' @param year Integer ending year.
#' @param source One of `"tapr"`, `"aeis"`.
#' @param refresh If `TRUE`, ignore the on-disk meta cache and re-fetch.
#' @return A tibble with columns `source`, `year`, `school_year`,
#'   `level`, `data_type`, `dataset`, `file_format`, `label`, `method`,
#'   `url`, `params`.
#' @examples
#' \dontrun{
#' txs_list_downloads(2024, "tapr")
#' }
#' @export
txs_list_downloads <- function(year,
                               source = c("tapr", "aeis"),
                               refresh = FALSE) {
  source <- match.arg(source)
  year <- normalize_year(year, source = source)
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
    aeis = discover_aeis_downloads(year)
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
      level = character(), data_type = character(), dataset = character(),
      file_format = character(), label = character(), method = character(),
      url = character(), params = character()
    ))
  }
  do.call(rbind, lapply(rows, function(r) {
    tibble::tibble(
      source      = r$source      %||% NA_character_,
      year        = as.integer(r$year %||% NA_integer_),
      school_year = r$school_year %||% NA_character_,
      level       = r$level       %||% NA_character_,
      data_type   = r$data_type   %||% NA_character_,
      dataset     = r$dataset     %||% NA_character_,
      file_format = r$file_format %||% NA_character_,
      label       = r$label       %||% NA_character_,
      method      = r$method      %||% "get",
      url         = r$url         %||% NA_character_,
      params      = r$params      %||% NA_character_
    )
  }))
}

# --- Generic form parsing ----------------------------------------------------

# Some TEA pages carry latin-1 bytes without a charset declaration;
# re-encode when a straight parse fails.
read_html_tolerant <- function(html_str) {
  tryCatch(
    rvest::read_html(html_str),
    error = function(e) {
      rvest::read_html(iconv(html_str, "latin1", "UTF-8", sub = "byte"))
    }
  )
}

# Parse the forms on a TEA download page into a list of
# list(action, method, hidden, groups) where `hidden` is a named list of
# hidden-input values and `groups` a named list of the value vectors of
# each radio group / select element. Pure function; easy to test
# against fixture HTML.
parse_download_forms <- function(html_str, page_url) {
  html <- read_html_tolerant(html_str)
  forms <- rvest::html_elements(html, "form")
  out <- list()
  for (form in forms) {
    action <- rvest::html_attr(form, "action") %||% ""
    if (!grepl("broker|aeis\\.cgi", action, ignore.case = TRUE)) next
    method <- toupper(rvest::html_attr(form, "method") %||% "GET")

    inputs <- rvest::html_elements(form, "input")
    types  <- tolower(rvest::html_attr(inputs, "type") %||% "text")
    names_ <- rvest::html_attr(inputs, "name")
    values <- rvest::html_attr(inputs, "value")

    hidden <- list()
    groups <- list()
    for (i in seq_along(inputs)) {
      nm <- names_[[i]]
      if (is.na(nm) || !nzchar(nm)) next
      if (identical(types[[i]], "hidden")) {
        hidden[[nm]] <- values[[i]] %||% ""
      } else if (identical(types[[i]], "radio")) {
        groups[[nm]] <- unique(c(groups[[nm]], values[[i]]))
      }
    }
    for (sel in rvest::html_elements(form, "select")) {
      nm <- rvest::html_attr(sel, "name")
      if (is.na(nm) || !nzchar(nm)) next
      opts <- rvest::html_attr(rvest::html_elements(sel, "option"), "value")
      opts <- opts[!is.na(opts) & nzchar(opts)]
      groups[[nm]] <- unique(c(groups[[nm]], opts))
    }

    out[[length(out) + 1L]] <- list(
      action = xml2::url_absolute(action, page_url),
      method = method,
      hidden = hidden,
      groups = groups
    )
  }
  out
}

# The 2024+ TAPR advanced page attaches inputs to the form by the HTML5
# `form="..."` attribute rather than nesting, which xml2 does not
# resolve; fall back to a whole-document scan when the broker form
# parses empty.
parse_download_forms_flat <- function(html_str, page_url) {
  html <- read_html_tolerant(html_str)
  inputs <- rvest::html_elements(html, "input")
  types  <- tolower(rvest::html_attr(inputs, "type") %||% "text")
  names_ <- rvest::html_attr(inputs, "name")
  values <- rvest::html_attr(inputs, "value")

  hidden <- list()
  groups <- list()
  for (i in seq_along(inputs)) {
    nm <- names_[[i]]
    if (is.na(nm) || !nzchar(nm)) next
    if (identical(types[[i]], "hidden")) {
      hidden[[nm]] <- values[[i]] %||% ""
    } else if (identical(types[[i]], "radio")) {
      groups[[nm]] <- unique(c(groups[[nm]], values[[i]]))
    }
  }

  action <- NA_character_
  method <- "GET"
  for (form in rvest::html_elements(html, "form")) {
    act <- rvest::html_attr(form, "action") %||% ""
    if (grepl("broker|aeis\\.cgi", act, ignore.case = TRUE)) {
      action <- xml2::url_absolute(act, page_url)
      method <- toupper(rvest::html_attr(form, "method") %||% "GET")
      break
    }
  }
  if (is.na(action) || !length(hidden)) return(list())
  list(list(action = action, method = method, hidden = hidden, groups = groups))
}

# Level-code mappings used by TEA's forms.
sumlev_to_level <- function(x) {
  switch(toupper(x), C = "campus", D = "district", R = "region", S = "state",
         NA_character_)
}

level_to_sumlev <- function(level) {
  switch(level, campus = "C", district = "D", region = "R", state = "S")
}

aeis_code_to_level <- function(x) {
  switch(tolower(x), c = "campus", d = "district", r = "region", s = "state",
         NA_character_)
}

# --- TAPR --------------------------------------------------------------------

discover_tapr_downloads <- function(year) {
  cat <- catalog_source("tapr")
  rows <- list()

  # 1. Dictionary workbooks + any static data links on the basic page.
  for (template in cat$basic_pages %||% character()) {
    page_url <- catalog_url(template, cat$base, year)
    got <- tryCatch({
      html_str <- fetch_html(page_url)
      parse_tapr_basic_page(html_str, page_url, year = year,
                            level_tokens = cat$level_tokens)
    }, error = function(e) list())
    if (length(got)) { rows <- c(rows, got); break }
  }

  # 2. Advanced (broker) datasets: one row per level x dataset.
  for (template in cat$advanced_pages %||% character()) {
    page_url <- catalog_url(template, cat$base, year)
    got <- tryCatch({
      html_str <- fetch_html(page_url)
      parse_tapr_advanced_page(html_str, page_url, year = year)
    }, error = function(e) list())
    if (length(got)) { rows <- c(rows, got); break }
  }

  # 3. Fallback: synthesize advanced rows from the catalog vocabulary so
  # a transient page-format change does not zero out discovery.
  if (!any(vapply(rows, function(r) identical(r$data_type, "advanced"), logical(1)))) {
    rows <- c(rows, tapr_advanced_fallback_rows(year, cat))
  }

  unique_rows(rows)
}

parse_tapr_basic_page <- function(html_str, page_url, year, level_tokens) {
  html <- read_html_tolerant(html_str)
  anchors <- rvest::html_elements(html, "a")
  hrefs <- rvest::html_attr(anchors, "href")
  labels <- trimws(rvest::html_text(anchors))
  keep <- !is.na(hrefs) &
    grepl("\\.(csv|txt|dat|xls|xlsx|zip)(\\?|$)", hrefs, ignore.case = TRUE)
  hrefs <- hrefs[keep]; labels <- labels[keep]
  if (!length(hrefs)) return(list())

  rows <- list()
  for (i in seq_along(hrefs)) {
    url <- xml2::url_absolute(hrefs[i], page_url)
    bn  <- basename(httr2::url_parse(url)$path)
    lvl <- classify_level(bn, level_tokens)
    fmt <- classify_format(bn)
    if (is.na(lvl) || is.na(fmt)) next
    # The statewide TAPR_*.xlsx workbooks are variable dictionaries,
    # not data files.
    data_type <- if (grepl("^tapr_", tolower(bn)) && fmt == "xlsx") {
      "dictionary"
    } else {
      "rates"
    }
    rows[[length(rows) + 1L]] <- list(
      source      = "tapr",
      year        = year,
      school_year = year_label(year),
      level       = lvl,
      data_type   = data_type,
      dataset     = NA_character_,
      file_format = fmt,
      label       = labels[i],
      method      = "get",
      url         = url,
      params      = NA_character_
    )
  }
  rows
}

parse_tapr_advanced_page <- function(html_str, page_url, year) {
  forms <- parse_download_forms(html_str, page_url)
  form <- Filter(function(f) length(f$groups$setpick) > 0, forms)
  if (!length(form)) {
    forms <- parse_download_forms_flat(html_str, page_url)
    form <- Filter(function(f) length(f$groups$setpick) > 0, forms)
  }
  if (!length(form)) return(list())
  form <- form[[1]]

  sumlevs <- form$groups$sumlev %||% c("C", "D", "R", "S")
  setpicks <- form$groups$setpick
  hidden <- form$hidden
  # The 2024+ page carries ccyy as a form-attached hidden input; older
  # pages carry year4/year2. Keep whatever the form declared.
  rows <- list()
  for (sl in sumlevs) {
    lvl <- sumlev_to_level(sl)
    if (is.na(lvl)) next
    for (sp in setpicks) {
      params <- c(hidden, list(sumlev = sl, setpick = sp))
      rows[[length(rows) + 1L]] <- list(
        source      = "tapr",
        year        = year,
        school_year = year_label(year),
        level       = lvl,
        data_type   = "advanced",
        dataset     = sp,
        file_format = "csv",
        label       = sprintf("TAPR advanced %s (%s)", sp, lvl),
        method      = tolower(form$method),
        url         = form$action,
        params      = encode_query_params(params)
      )
    }
  }
  rows
}

# Broker parameters reconstructed from the catalog when live form
# parsing fails. Uses the verified per-era conventions.
tapr_advanced_fallback_rows <- function(year, cat) {
  setpicks <- unlist(cat$setpick_fallback %||% list())
  if (!length(setpicks)) return(list())
  rows <- list()
  for (lvl in c("campus", "district", "region", "state")) {
    for (sp in setpicks) {
      params <- if (year >= 2024) {
        list(
          `_service` = "marykay", `_program` = "perfrept.perfmast.sas",
          `_debug` = "0", ccyy = as.character(year),
          prgopt = sprintf("%d/tapr/Advanced Download/getdata_%d.sas", year, year),
          sumlev = level_to_sumlev(lvl), setpick = sp
        )
      } else {
        list(
          `_service` = "marykay", `_program` = "perfrept.perfmast.sas",
          `_debug` = "0",
          prgopt = sprintf("%d/tapr/tapr_download.sas", year),
          year4 = as.character(year),
          year2 = sprintf("%02d", year %% 100L),
          topic = "acct", title = "Data Download",
          sumlev = level_to_sumlev(lvl), setpick = sp
        )
      }
      rows[[length(rows) + 1L]] <- list(
        source      = "tapr",
        year        = year,
        school_year = year_label(year),
        level       = lvl,
        data_type   = "advanced",
        dataset     = sp,
        file_format = "csv",
        label       = sprintf("TAPR advanced %s (%s)", sp, lvl),
        method      = if (year >= 2024) "get" else "post",
        url         = catalog_broker_url(),
        params      = encode_query_params(params)
      )
    }
  }
  rows
}

# Thin fetch wrapper so tests can stub just the network half.
fetch_html <- function(page_url) {
  resp <- http_get(page_url)
  httr2::resp_body_string(resp)
}

# Classify a filename to a level by token matching: filenames like
# "TAPR_campus_2024.xlsx" contain the level as a separate token, while
# legacy files like "cref.dat" use short prefixes. Tokens are checked
# longest-first so "district" wins over "dis".
classify_level <- function(filename, tokens = NULL) {
  if (is.null(tokens)) tokens <- list(
    campus   = c("campus", "camp", "cs"),
    district = c("district", "dist", "dis"),
    region   = c("region", "reg"),
    state    = c("state")
  )
  bn <- tolower(filename)
  parts <- strsplit(bn, "[^a-z0-9]+")[[1]]
  parts <- parts[nzchar(parts)]

  pairs <- do.call(rbind, lapply(names(tokens), function(lvl) {
    data.frame(level = lvl, token = tolower(unlist(tokens[[lvl]])),
               stringsAsFactors = FALSE)
  }))
  pairs <- pairs[order(-nchar(pairs$token)), , drop = FALSE]

  # 1. Exact token match ("tapr_campus_2024" -> "campus").
  for (i in seq_len(nrow(pairs))) {
    if (pairs$token[i] %in% parts) return(pairs$level[i])
  }
  # 2. Legacy prefix match ("cref" -> campus via "c"? no -- only the
  # documented prefixes, matched against the first token).
  first <- parts[1] %||% ""
  for (i in seq_len(nrow(pairs))) {
    if (startsWith(first, pairs$token[i])) return(pairs$level[i])
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
  key <- vapply(
    rows,
    function(r) paste(r$level, r$data_type, r$dataset %||% "", r$file_format,
                      r$url, r$params %||% ""),
    character(1)
  )
  rows[!duplicated(key)]
}

# --- AEIS --------------------------------------------------------------------

discover_aeis_downloads <- function(year) {
  cat <- catalog_source("aeis")
  page_url <- catalog_url(cat$download_form, cat$base, year)
  rows <- tryCatch({
    html_str <- fetch_html(page_url)
    parse_aeis_download_form(html_str, page_url, year = year)
  }, error = function(e) list())
  if (!length(rows)) {
    rows <- aeis_fallback_rows(year, cat)
  }
  rows
}

parse_aeis_download_form <- function(html_str, page_url, year) {
  forms <- parse_download_forms(html_str, page_url)
  form <- Filter(
    function(f) length(f$groups$file) > 0 && length(f$groups$level) > 0,
    forms
  )
  if (!length(form)) return(list())
  form <- form[[1]]

  rows <- list()
  for (lc in form$groups$level) {
    lvl <- aeis_code_to_level(lc)
    if (is.na(lvl)) next
    for (ds in form$groups$file) {
      params <- c(form$hidden, list(level = lc, file = ds, suf = ".dat"))
      rows[[length(rows) + 1L]] <- list(
        source      = "aeis",
        year        = year,
        school_year = year_label(year),
        level       = lvl,
        data_type   = "rates",
        dataset     = ds,
        file_format = "txt",
        label       = sprintf("AEIS %s (%s)", ds, lvl),
        method      = tolower(form$method),
        url         = form$action,
        params      = encode_query_params(params)
      )
    }
  }
  rows
}

aeis_fallback_rows <- function(year, cat) {
  files <- unlist(cat$file_fallback %||% list())
  if (!length(files)) return(list())
  cgi <- gsub("\\{year\\}", as.character(year), cat$cgi)
  rows <- list()
  for (lvl in c("campus", "district", "region", "state")) {
    lc <- substr(lvl, 1, 1)
    for (ds in files) {
      params <- list(level = lc, file = ds, suf = ".dat")
      rows[[length(rows) + 1L]] <- list(
        source      = "aeis",
        year        = year,
        school_year = year_label(year),
        level       = lvl,
        data_type   = "rates",
        dataset     = ds,
        file_format = "txt",
        label       = sprintf("AEIS %s (%s)", ds, lvl),
        method      = "post",
        url         = cgi,
        params      = encode_query_params(params)
      )
    }
  }
  rows
}
