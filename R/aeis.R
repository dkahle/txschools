#' Download an AEIS (Academic Excellence Indicator System) file
#'
#' Downloads one statewide AEIS data file served by TEA's per-year
#' download CGI. Each file is identified by a level and a dataset code
#' (e.g. `"ref"` for reference information, `"stud"` for student
#' information, `"fin"` for finance); use [txs_list_downloads()] to see
#' the codes TEA publishes for a year.
#'
#' Coverage: this package supports the school years 2003-04 through
#' 2011-12 (requested as ending years 2004 through 2012), the span TEA
#' serves through its AEIS download forms. TEA's AEIS archive pages
#' reach further back, but those years use different, unsupported
#' publication formats.
#'
#' @inheritParams txs_get_tapr_file
#' @param geography Optional. A character vector of campus or district
#'   numbers to filter the parsed file to. `NULL` returns all rows.
#' @param dataset AEIS dataset code, e.g. `"ref"`, `"stud"`, `"fin"`.
#'   Case-insensitive; defaults to `"ref"`.
#' @param layout If `TRUE`, also download the record layout (`.lyt`)
#'   for the dataset and attach it as `attr(out, "layout")` (a
#'   character vector of lines).
#' @return A tibble with a `txschools` attribute.
#' @export
txs_get_aeis <- function(year,
                         level = c("campus", "district", "region", "state"),
                         geography = NULL,
                         dataset = "ref",
                         layout = FALSE,
                         cache = TRUE,
                         refresh = FALSE,
                         output = c("tidy", "wide", "raw"),
                         keep_raw = FALSE,
                         timeout = 60,
                         verbose = TRUE) {
  output <- match.arg(output)
  level  <- match.arg(level, c("campus", "district", "region", "state"))
  year   <- normalize_year(year, source = "aeis")
  cache  <- isTRUE(cache)
  dataset <- tolower(as.character(dataset)[1])

  downloads <- if (cache) {
    txs_list_downloads(year, source = "aeis", refresh = refresh)
  } else {
    with_temporary_cache_dir(
      txs_list_downloads(year, source = "aeis", refresh = refresh)
    )
  }
  hits <- downloads[
    downloads$level == level &
      !is.na(downloads$dataset) & tolower(downloads$dataset) == dataset,
    , drop = FALSE
  ]
  if (!nrow(hits)) {
    available <- sort(unique(downloads$dataset[downloads$level == level]))
    stop(
      sprintf("Unknown AEIS dataset code %s for year=%d, level=%s.\n",
              dataset, year, level),
      "Available: ", paste(available, collapse = ", "),
      call. = FALSE
    )
  }
  hits <- hits[1L, , drop = FALSE]

  url <- hits$url
  filename <- download_filename(hits)
  dest <- cache_path("aeis", year, level, "rates", file = filename)
  if (!cache) dest <- temp_download_path(filename)

  used_cache <- FALSE
  if (cache && !refresh && file.exists(dest)) {
    if (verbose) cli::cli_alert_info("Using cached file: {dest}")
    used_cache <- TRUE
    meta <- read_sidecar(dest) %||% list(
      source_url = url, retrieved_at = NA_character_,
      sha256 = sha256_file(dest), size_bytes = file.size(dest),
      content_type = NA_character_
    )
  } else {
    if (verbose) cli::cli_alert_info("Downloading: {url}")
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    info <- http_download(
      url, dest, timeout = timeout,
      method = hits$method %||% "post", params = hits$params
    )
    check_broker_data_response(dest, hits)
    meta <- list(
      source       = "aeis",
      year         = year,
      school_year  = year_label(year),
      level        = level,
      data_type    = "rates",
      dataset      = hits$dataset,
      file_format  = hits$file_format,
      source_url   = url,
      method       = hits$method,
      params       = hits$params,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  df_raw <- read_tapr_file(dest, file_format = hits$file_format)
  if (!is.null(geography)) df_raw <- filter_by_geography(df_raw, level, geography)

  out <- switch(
    output,
    raw  = to_raw(df_raw),
    wide = to_wide(df_raw, year = year, level = level),
    tidy = to_tidy(df_raw, year = year, level = level)
  )
  attr(out, "txschools") <- list(
    source = "aeis", year = year, school_year = year_label(year),
    level = level, data_type = "rates", dataset = hits$dataset,
    file_format = hits$file_format,
    source_url = url, retrieved_at = meta$retrieved_at,
    sha256 = meta$sha256, size_bytes = meta$size_bytes,
    cache_path = dest, used_cache = used_cache,
    masking_values = mask_codes()
  )
  if (isTRUE(keep_raw)) attr(out, "raw") <- df_raw
  if (isTRUE(layout)) {
    attr(out, "layout") <- txs_get_aeis_layout(
      hits, year = year, level = level, cache = cache,
      refresh = refresh, timeout = timeout, verbose = verbose
    )
  }
  out
}

# Fetch the record layout (.lyt) companion of an AEIS dataset.
txs_get_aeis_layout <- function(hit, year, level, cache, refresh,
                                timeout, verbose) {
  params <- decode_query_params(hit$params)
  params$suf <- ".lyt"
  filename <- sub("\\.dat$", ".lyt", download_filename(hit))
  if (identical(filename, download_filename(hit))) {
    filename <- paste0(filename, ".lyt")
  }
  dest <- cache_path("aeis", year, level, "layout", file = filename)
  if (!cache) dest <- temp_download_path(filename)
  if (!(cache && !refresh && file.exists(dest))) {
    if (verbose) cli::cli_alert_info("Downloading layout: {hit$url}")
    info <- http_download(
      hit$url, dest, timeout = timeout,
      method = hit$method %||% "post", params = encode_query_params(params)
    )
    if (cache) {
      write_sidecar(dest, list(
        source = "aeis", year = year, school_year = year_label(year),
        level = level, data_type = "layout", dataset = hit$dataset,
        file_format = "lyt", source_url = hit$url,
        method = hit$method, params = encode_query_params(params),
        retrieved_at = info$retrieved_at, sha256 = info$sha256,
        size_bytes = info$size_bytes, content_type = info$content_type
      ))
    }
  }
  readLines(dest, warn = FALSE)
}