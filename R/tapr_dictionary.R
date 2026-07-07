#' Download the TAPR variable dictionary
#'
#' TEA publishes one "TAPR Data in Excel" workbook per year and level
#' (`TAPR_campus_2024.xlsx`, ...). Despite the billing, these workbooks
#' are variable dictionaries, not data: each sheet lists the variables
#' of one advanced-download dataset with its code and human-readable
#' label. This function downloads (and caches) the workbook and returns
#' it as one tidy tibble.
#'
#' @inheritParams txs_get_tapr_file
#' @return A tibble with columns `year`, `school_year`, `level`,
#'   `sheet`, `dataset`, `variable`, `label`, and a `txschools`
#'   attribute.
#' @examples
#' \dontrun{
#' dict <- txs_get_tapr_dictionary(2024, "campus")
#' dict[grepl("Attendance", dict$label), ]
#' }
#' @export
txs_get_tapr_dictionary <- function(year,
                                    level = c("campus", "district", "region", "state"),
                                    cache = TRUE,
                                    refresh = FALSE,
                                    timeout = 60,
                                    verbose = TRUE) {
  year  <- normalize_year(year, source = "tapr")
  level <- match.arg(level)
  cache <- isTRUE(cache)

  downloads <- if (cache) {
    txs_list_downloads(year, source = "tapr", refresh = refresh)
  } else {
    with_temporary_cache_dir(
      txs_list_downloads(year, source = "tapr", refresh = refresh)
    )
  }
  hits <- downloads[
    downloads$level == level & downloads$data_type == "dictionary",
    , drop = FALSE
  ]
  if (!nrow(hits)) {
    stop(sprintf(
      "No TAPR dictionary workbook found for year=%d, level=%s.",
      year, level
    ), call. = FALSE)
  }
  hits <- hits[1L, , drop = FALSE]

  url <- hits$url
  filename <- download_filename(hits)
  dest <- cache_path("tapr", year, level, "dictionary", file = filename)
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
      source       = "tapr",
      year         = year,
      school_year  = year_label(year),
      level        = level,
      data_type    = "dictionary",
      file_format  = "xlsx",
      source_url   = url,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  out <- read_tapr_dictionary(dest, year = year, level = level)
  attr(out, "txschools") <- list(
    source       = "tapr",
    year         = year,
    school_year  = year_label(year),
    level        = level,
    data_type    = "dictionary",
    source_url   = url,
    retrieved_at = meta$retrieved_at,
    sha256       = meta$sha256,
    cache_path   = dest,
    used_cache   = used_cache
  )
  out
}

read_tapr_dictionary <- function(path, year, level) {
  sheets <- readxl::excel_sheets(path)
  rows <- lapply(sheets, function(s) {
    df <- tryCatch(
      readxl::read_excel(path, sheet = s, col_types = "text"),
      error = function(e) NULL
    )
    if (is.null(df) || !all(c("DATA", "NAME", "LABEL") %in% names(df))) {
      return(NULL)
    }
    tibble::tibble(
      year        = as.integer(year),
      school_year = year_label(year),
      level       = level,
      sheet       = s,
      dataset     = as.character(df$DATA),
      variable    = as.character(df$NAME),
      label       = as.character(df$LABEL)
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    stop("Workbook did not contain any DATA/NAME/LABEL dictionary sheets: ",
         path, call. = FALSE)
  }
  dplyr::bind_rows(rows)
}
