#' Download an AEIS (Academic Excellence Indicator System) file
#'
#' Coverage: school years 2003-04 through 2011-12, requested as ending
#' years 2004 through 2012.
#'
#' @inheritParams txs_get_tapr_file
#' @param geography Optional. A character vector of campus or district
#'   numbers to filter the parsed file to. `NULL` returns all rows.
#' @param data_type Currently `"rates"`.
#' @param file_format `"csv"`, `"txt"`, or `"xlsx"`.
#' @return A tibble with a `txschools` attribute.
#' @export
txs_get_aeis <- function(year,
                         level = c("campus", "district", "region", "state"),
                         geography = NULL,
                         data_type = c("rates"),
                         file_format = c("csv", "txt", "xlsx"),
                         cache = TRUE,
                         refresh = FALSE,
                         output = c("tidy", "wide", "raw"),
                         keep_raw = FALSE,
                         timeout = 60,
                         verbose = TRUE) {
  data_type   <- match.arg(data_type)
  file_format <- match.arg(file_format)
  output      <- match.arg(output)
  level       <- match.arg(level, c("campus", "district", "region", "state"))

  year_int <- normalize_year(year)
  if (year_int < TXS_FIRST_AEIS_YEAR || year_int > TXS_LAST_AEIS_YEAR) {
    stop(sprintf(
      "AEIS covers %d-%d only; got %d.",
      TXS_FIRST_AEIS_YEAR, TXS_LAST_AEIS_YEAR, year_int
    ), call. = FALSE)
  }

  generic_get(
    source = "aeis", year = year_int, level = level, geography = geography,
    data_type = data_type, file_format = file_format,
    cache = cache, refresh = refresh, output = output,
    keep_raw = keep_raw, timeout = timeout, verbose = verbose
  )
}

# Shared get-and-parse implementation. Used by src/aeis; tapr keeps its
# own copy because TAPR has additional disambiguation logic.
generic_get <- function(source, year, level, geography, data_type,
                        file_format, cache, refresh, output,
                        keep_raw, timeout, verbose) {
  cache <- isTRUE(cache)
  downloads <- if (cache) {
    txs_list_downloads(year, source = source, refresh = refresh)
  } else {
    with_temporary_cache_dir(
      txs_list_downloads(year, source = source, refresh = refresh)
    )
  }
  hits <- downloads[
    downloads$level == level &
      downloads$data_type == data_type &
      downloads$file_format == file_format,
    , drop = FALSE
  ]
  if (!nrow(hits)) {
    stop(sprintf(
      "No %s download matched year=%d, level=%s, data_type=%s, file_format=%s.",
      toupper(source), year, level, data_type, file_format
    ), call. = FALSE)
  }
  url  <- hits$url[1]
  filename <- basename(httr2::url_parse(url)$path)
  dest <- cache_path(
    source, year, level, data_type,
    file = filename
  )
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
    info <- http_download(url, dest, timeout = timeout)
    meta <- list(
      source       = source,
      year         = year,
      school_year  = year_label(year),
      level        = level,
      data_type    = data_type,
      file_format  = file_format,
      source_url   = url,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  df_raw <- read_tapr_file(dest, file_format = file_format)
  if (!is.null(geography)) df_raw <- filter_by_geography(df_raw, level, geography)

  out <- switch(
    output,
    raw  = to_raw(df_raw),
    wide = to_wide(df_raw, year = year, level = level),
    tidy = to_tidy(df_raw, year = year, level = level)
  )
  attr(out, "txschools") <- list(
    source = source, year = year, school_year = year_label(year),
    level = level, data_type = data_type, file_format = file_format,
    source_url = url, retrieved_at = meta$retrieved_at,
    sha256 = meta$sha256, size_bytes = meta$size_bytes,
    cache_path = dest, used_cache = used_cache,
    masking_values = mask_codes()
  )
  if (isTRUE(keep_raw)) attr(out, "raw") <- df_raw
  out
}
