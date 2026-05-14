#' Download a TAPR file
#'
#' Downloads (or returns the cached copy of) a single Texas Academic
#' Performance Reports file for a given school year, level, data type,
#' and file format.
#'
#' @param year Integer ending year (e.g. `2024` for 2023-24).
#' @param level One of `"campus"`, `"district"`, `"region"`, `"state"`.
#' @param geography Optional. A character vector of campus or district
#'   numbers to filter the parsed file to. `NULL` returns all rows for
#'   structured downloads. For `file_format = "html"`, supply exactly
#'   one campus, district, or region identifier.
#' @param data_type Either `"rates"` (basic) or `"advanced"`
#'   (numerators, denominators, and rates).
#' @param file_format `"csv"`, `"txt"`, `"xlsx"`, or `"html"`. `"html"`
#'   requests a public TAPR/TPRS report page for one requested geography
#'   when TEA does not expose the current year as a structured download
#'   file.
#' @param cache If `TRUE`, reuse a cached copy when one exists.
#' @param refresh If `TRUE`, re-download even if cached.
#' @param output `"tidy"` (long, masking-aware), `"wide"` (raw with
#'   human-readable labels attached), or `"raw"` (as parsed).
#' @param keep_raw If `TRUE`, attach the raw parsed frame as
#'   `attr(out, "raw")`.
#' @param timeout HTTP timeout in seconds.
#' @param verbose Print progress messages.
#' @return A tibble with a `txschools` attribute carrying source/metadata.
#' @export
txs_get_tapr <- function(year,
                         level = c("campus", "district", "region", "state"),
                         geography = NULL,
                         data_type = c("rates", "advanced"),
                         file_format = c("csv", "txt", "xlsx", "html"),
                         cache = TRUE,
                         refresh = FALSE,
                         output = c("tidy", "wide", "raw"),
                         keep_raw = FALSE,
                         timeout = 60,
                         verbose = TRUE) {
  year        <- normalize_year(year)
  data_type   <- match.arg(data_type)
  file_format <- match.arg(file_format)
  output      <- match.arg(output)
  level       <- match.arg(level, c("campus", "district", "region", "state"))
  cache       <- isTRUE(cache)

  if (identical(file_format, "html")) {
    return(txs_get_tapr_html_report(
      year = year, level = level, geography = geography,
      data_type = data_type, cache = cache, refresh = refresh,
      output = output, keep_raw = keep_raw, timeout = timeout,
      verbose = verbose
    ))
  }

  downloads <- if (cache) {
    txs_list_downloads(year, source = "tapr", refresh = refresh)
  } else {
    with_temporary_cache_dir(
      txs_list_downloads(year, source = "tapr", refresh = refresh)
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
      "No TAPR download matched year=%d, level=%s, data_type=%s, file_format=%s.",
      year, level, data_type, file_format
    ), call. = FALSE)
  }
  if (nrow(hits) > 1L) {
    # Take the first; emit a warning identifying the alternatives.
    cli::cli_alert_warning(
      "Multiple TAPR downloads matched; using the first. Others: {hits$url[-1]}"
    )
    hits <- hits[1L, , drop = FALSE]
  }
  url <- hits$url
  filename <- basename(httr2::url_parse(url)$path)
  dest <- cache_path(
    "tapr", year, level, data_type,
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
      source       = "tapr",
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

  if (!is.null(geography)) {
    df_raw <- filter_by_geography(df_raw, level, geography)
  }

  out <- switch(
    output,
    raw  = to_raw(df_raw),
    wide = to_wide(df_raw, year = year, level = level),
    tidy = to_tidy(df_raw, year = year, level = level)
  )

  attr(out, "txschools") <- list(
    source       = "tapr",
    year         = year,
    school_year  = year_label(year),
    level        = level,
    data_type    = data_type,
    file_format  = file_format,
    source_url   = url,
    retrieved_at = meta$retrieved_at,
    sha256       = meta$sha256,
    size_bytes   = meta$size_bytes,
    cache_path   = dest,
    used_cache   = used_cache,
    masking_values = mask_codes()
  )
  if (isTRUE(keep_raw)) attr(out, "raw") <- df_raw
  out
}

txs_get_tapr_html_report <- function(year, level, geography, data_type,
                                     cache, refresh, output, keep_raw,
                                     timeout, verbose) {
  if (!identical(data_type, "rates")) {
    stop(
      "`file_format = \"html\"` currently supports `data_type = \"rates\"` only.",
      call. = FALSE
    )
  }
  if (is.null(geography)) {
    if (identical(level, "state")) {
      geography <- "000000000"
    } else {
      stop(
        "`file_format = \"html\"` requires a single campus, district, or region ",
        "identifier in `geography`.",
        call. = FALSE
      )
    }
  }
  if (length(geography) != 1L || is.na(geography) || !nzchar(as.character(geography))) {
    stop(
      "`file_format = \"html\"` requires exactly one non-missing `geography` value.",
      call. = FALSE
    )
  }

  url <- tapr_html_report_url(year, level, geography)
  filename <- tapr_html_report_filename(level, geography)
  dest <- cache_path("tapr", year, level, data_type, file = filename)
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
    info <- http_download(url, dest, timeout = timeout)
    meta <- list(
      source       = "tapr",
      year         = year,
      school_year  = year_label(year),
      level        = level,
      geography    = as.character(geography),
      data_type    = data_type,
      file_format  = "html",
      source_url   = url,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  df_raw <- read_tapr_html_report(dest, level = level)
  out <- switch(
    output,
    raw  = to_raw(df_raw),
    wide = to_wide(df_raw, year = year, level = level),
    tidy = to_tidy_tapr_html_report(df_raw, year = year, level = level)
  )

  attr(out, "txschools") <- list(
    source       = "tapr",
    year         = year,
    school_year  = year_label(year),
    level        = level,
    geography    = as.character(geography),
    data_type    = data_type,
    file_format  = "html",
    source_url   = url,
    retrieved_at = meta$retrieved_at,
    sha256       = meta$sha256,
    size_bytes   = meta$size_bytes,
    cache_path   = dest,
    used_cache   = used_cache,
    masking_values = mask_codes()
  )
  if (isTRUE(keep_raw)) attr(out, "raw") <- df_raw
  out
}

tapr_html_report_url <- function(year, level, geography) {
  lev <- switch(
    level,
    campus   = "C",
    district = "D",
    region   = "R",
    state    = "S"
  )
  paste0(
    "https://rptsvr1.tea.texas.gov/cgi/sas/broker?",
    "_debug=0&_program=perfrept.perfmast.sas&_service=marykay",
    "&ccyy=", as.integer(year),
    "&id=", utils::URLencode(as.character(geography), reserved = TRUE),
    "&lev=", lev,
    "&prgopt=reports/tapr/student.sas"
  )
}

tapr_html_report_filename <- function(level, geography) {
  id <- gsub("[^A-Za-z0-9_-]+", "_", as.character(geography))
  sprintf("tapr_%s_%s_student.html", level, id)
}

read_tapr_html_report <- function(path, level) {
  html <- rvest::read_html(path)
  tables <- rvest::html_table(html, fill = TRUE, trim = FALSE)
  if (!length(tables)) {
    stop("Could not locate any tables in the TAPR HTML report.", call. = FALSE)
  }

  has_student_rows <- vapply(tables, function(tab) {
    ncol(tab) >= 3L &&
      any(grepl("^\\s*Total Students\\b", as.character(tab[[1]]), ignore.case = TRUE))
  }, logical(1))
  idx <- which(has_student_rows)[1]
  if (is.na(idx)) {
    stop("Could not locate the student-information table in the TAPR HTML report.", call. = FALSE)
  }

  tab <- tables[[idx]]
  tab[] <- lapply(tab, function(x) {
    x <- trimws(as.character(x))
    x[is.na(x)] <- ""
    x
  })
  tab <- tab[rowSums(as.matrix(tab != "")) > 0, , drop = FALSE]

  entity <- switch(
    level,
    campus   = "campus",
    district = "district",
    region   = "region",
    state    = "state"
  )
  n <- min(ncol(tab), 5L)
  out <- tab[seq_len(n)]
  nms <- switch(
    as.character(n),
    "3" = c("measure", paste0(entity, "_count"), paste0(entity, "_percent")),
    "4" = c("measure", paste0(entity, "_count"), paste0(entity, "_percent"), "state"),
    c("measure", paste0(entity, "_count"), paste0(entity, "_percent"), "district", "state")
  )
  names(out) <- nms
  tibble::as_tibble(out)
}

to_tidy_tapr_html_report <- function(df, year, level) {
  value_cols <- setdiff(names(df), "measure")
  if (!length(value_cols)) return(df)

  long <- tidyr::pivot_longer(
    df,
    cols = dplyr::all_of(value_cols),
    names_to = "variable_code",
    values_to = "value",
    values_transform = list(value = as.character)
  )
  ms <- mask_strip(long$value)
  long$value_num <- ms$value_num
  long$masked <- ms$masked
  long$mask_code <- ms$mask_code
  long$year <- as.integer(year)
  long$school_year <- year_label(year)
  long$level <- level

  front <- c("measure", "year", "school_year", "level",
             "variable_code", "value", "value_num", "masked", "mask_code")
  long[, c(intersect(front, names(long)),
           setdiff(names(long), front)), drop = FALSE]
}

# Geography filter: tries to find a column whose name matches a level-
# specific id pattern, then keeps rows whose value matches one of the
# requested ids.
filter_by_geography <- function(df, level, ids) {
  patterns <- switch(
    level,
    campus   = c("^CAMPUS$", "^CAMPUS_ID$", "^CAMPUS_NUMBER$", "CAMPUS"),
    district = c("^DISTRICT$", "^DISTRICT_ID$", "^DISTRICT_NUMBER$", "DISTRICT"),
    region   = c("^REGION$", "REGION"),
    state    = c("^STATE$")
  )
  col <- NULL
  for (pat in patterns) {
    hit <- grep(pat, names(df), ignore.case = TRUE, value = TRUE)
    if (length(hit)) { col <- hit[1]; break }
  }
  if (is.null(col)) {
    cli::cli_alert_warning(
      "Could not find a {level} id column; returning unfiltered."
    )
    return(df)
  }
  df[as.character(df[[col]]) %in% as.character(ids), , drop = FALSE]
}
