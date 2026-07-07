#' Download semantic TAPR datasets
#'
#' Downloads public TAPR/TPRS HTML reports for one or more years and
#' geographies, then returns the report as a named list of semantic
#' datasets such as student grade distribution, ethnicity, sex, and
#' other cohorts. Use [txs_get_tapr_file()] for the lower-level
#' structured TAPR downloads.
#'
#' @param year Integer vector of ending years (e.g. `2025` for 2024-25).
#' @param level One of `"campus"`, `"district"`, `"region"`, `"state"`.
#' @param geography Character vector of campus, district, region, or state
#'   identifiers. For `level = "state"`, `NULL` uses `"000000000"`.
#' @param datasets Optional character vector of dataset keys from
#'   [txs_list_tapr_datasets()]. `NULL` requests all known keys.
#' @param cache If `TRUE`, reuse a cached copy when one exists.
#' @param refresh If `TRUE`, re-download even if cached.
#' @param db Optional DuckDB path or DBI connection. If supplied, the
#'   returned semantic tables are written to the database.
#' @param timeout HTTP timeout in seconds.
#' @param verbose Print progress messages.
#' @return A `tapr` named list of tibbles.
#' @export
txs_get_tapr <- function(year,
                         level = c("campus", "district", "region", "state"),
                         geography = NULL,
                         datasets = NULL,
                         cache = TRUE,
                         refresh = FALSE,
                         db = NULL,
                         timeout = 60,
                         verbose = TRUE) {
  level <- match.arg(level, c("campus", "district", "region", "state"))
  years <- vapply(year, normalize_year, integer(1), source = "tapr")
  years <- sort(unique(years))

  if (is.null(geography)) {
    if (identical(level, "state")) {
      geography <- "000000000"
    } else {
      stop("`geography` is required for campus, district, and region TAPR pulls.",
           call. = FALSE)
    }
  }
  geography <- as.character(geography)
  geography <- geography[!is.na(geography) & nzchar(geography)]
  if (!length(geography)) {
    stop("`geography` must contain at least one non-missing identifier.",
         call. = FALSE)
  }

  catalog <- txs_list_tapr_datasets()
  if (is.null(datasets)) {
    datasets <- catalog$key
  } else {
    datasets <- unique(as.character(datasets))
    bad <- setdiff(datasets, catalog$key)
    if (length(bad)) {
      stop(
        if (length(bad) == 1L) "Unknown TAPR dataset key: " else "Unknown TAPR dataset keys: ",
        paste(bad, collapse = ", "),
        call. = FALSE
      )
    }
  }

  out <- collect_tapr_semantic(
    years = years, level = level, geography = geography,
    datasets = datasets, cache = isTRUE(cache), refresh = refresh,
    timeout = timeout, verbose = verbose
  )

  if (!is.null(db)) {
    txs_write_tapr_db(out, db = db, overwrite = TRUE)
  }
  out
}

#' Download a TAPR data file
#'
#' Downloads (or returns the cached copy of) a single Texas Academic
#' Performance Reports statewide data file. TEA serves these through its
#' SAS-broker "Advanced Download" interface: one CSV per year, level,
#' and dataset code (e.g. `"REF"` for campus/district reference
#' information, `"STAAR1"` for STAAR performance). Use
#' [txs_list_downloads()] to see the codes available for a year, and
#' [txs_get_tapr()] for per-campus semantic datasets.
#'
#' @param year Integer ending year (e.g. `2024` for 2023-24).
#' @param level One of `"campus"`, `"district"`, `"region"`, `"state"`.
#' @param geography Optional. A character vector of campus or district
#'   numbers to filter the parsed file to. `NULL` returns all rows for
#'   statewide downloads. For `file_format = "html"`, supply exactly
#'   one campus, district, or region identifier.
#' @param dataset Dataset code for `data_type = "advanced"`, e.g.
#'   `"REF"`, `"STAAR1"`, `"GRAD"`. Case-insensitive. Required for
#'   advanced downloads; see [txs_list_downloads()].
#' @param data_type `"advanced"` (the statewide data files: numerators,
#'   denominators, and rates) or `"rates"` (legacy static rates-only
#'   files, when TEA publishes them).
#' @param file_format `"csv"` (statewide files) or `"html"` (a public
#'   TAPR/TPRS report page for one requested geography).
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
txs_get_tapr_file <- function(year,
                              level = c("campus", "district", "region", "state"),
                              geography = NULL,
                              dataset = NULL,
                              data_type = c("advanced", "rates"),
                              file_format = c("csv", "txt", "xlsx", "html"),
                              cache = TRUE,
                              refresh = FALSE,
                              output = c("tidy", "wide", "raw"),
                              keep_raw = FALSE,
                              timeout = 60,
                              verbose = TRUE) {
  year        <- normalize_year(year, source = "tapr")
  data_type_supplied <- !missing(data_type)
  data_type   <- match.arg(data_type)
  file_format <- match.arg(file_format)
  output      <- match.arg(output)
  level       <- match.arg(level, c("campus", "district", "region", "state"))
  cache       <- isTRUE(cache)

  if (identical(file_format, "html")) {
    # HTML report pages carry rates only. `data_type` defaults to
    # "advanced" via match.arg, so only an *explicit* advanced request
    # is a contradiction worth stopping for.
    if (data_type_supplied && identical(data_type, "advanced")) {
      stop(
        "`file_format = \"html\"` serves TEA's rates-only report pages; ",
        "advanced data is not published as HTML. Use `file_format = \"csv\"` ",
        "with a `dataset` code for advanced downloads.",
        call. = FALSE
      )
    }
    return(txs_get_tapr_html_report(
      year = year, level = level, geography = geography,
      data_type = "rates", cache = cache, refresh = refresh,
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

  if (identical(data_type, "advanced")) {
    available <- sort(unique(hits$dataset))
    if (is.null(dataset)) {
      stop(
        "Advanced TAPR downloads are split into datasets; supply `dataset`.\n",
        "Available for ", year, " ", level, ": ",
        paste(available, collapse = ", "),
        call. = FALSE
      )
    }
    dataset <- toupper(as.character(dataset)[1])
    hits <- hits[!is.na(hits$dataset) & toupper(hits$dataset) == dataset,
                 , drop = FALSE]
    if (!nrow(hits)) {
      stop(
        sprintf("Unknown TAPR dataset code %s for year=%d, level=%s.\n",
                dataset, year, level),
        "Available: ", paste(available, collapse = ", "),
        call. = FALSE
      )
    }
  }

  if (!nrow(hits)) {
    msg <- sprintf(
      "No TAPR download matched year=%d, level=%s, data_type=%s, file_format=%s.",
      year, level, data_type, file_format
    )
    if (identical(data_type, "rates")) {
      msg <- paste0(
        msg,
        "\nTEA does not publish static rates-only files for most years; ",
        "use `data_type = \"advanced\"` with a `dataset` code, or ",
        "`txs_get_tapr()` for per-campus reports."
      )
    }
    stop(msg, call. = FALSE)
  }
  if (nrow(hits) > 1L) {
    # Take the first; emit a warning identifying the alternatives.
    cli::cli_alert_warning(
      "Multiple TAPR downloads matched; using the first. Others: {hits$url[-1]}"
    )
    hits <- hits[1L, , drop = FALSE]
  }

  url <- hits$url
  filename <- download_filename(hits)
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
    info <- http_download(
      url, dest, timeout = timeout,
      method = hits$method %||% "get", params = hits$params
    )
    check_broker_data_response(dest, hits)
    meta <- list(
      source       = "tapr",
      year         = year,
      school_year  = year_label(year),
      level        = level,
      data_type    = data_type,
      dataset      = hits$dataset,
      file_format  = file_format,
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
    dataset      = hits$dataset,
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

# Synthesize a cache filename for a downloads row. Broker rows have no
# meaningful basename in the URL.
download_filename <- function(row) {
  bn <- basename(httr2::url_parse(row$url)$path)
  if (grepl("\\.(csv|txt|dat|xls|xlsx|zip)$", bn, ignore.case = TRUE)) {
    return(bn)
  }
  ds <- if (!is.na(row$dataset %||% NA_character_)) {
    paste0("_", tolower(row$dataset))
  } else {
    ""
  }
  ext <- switch(row$file_format, csv = "csv", txt = "dat", xlsx = "xlsx", "dat")
  sprintf("%s_%s_%d%s.%s", row$source, row$level, row$year, ds, ext)
}

# TEA's SAS broker signals "no such dataset for this level" (and other
# soft failures) by returning an HTML page instead of data. Detect it
# and fail loudly rather than caching junk.
check_broker_data_response <- function(dest, row) {
  head_bytes <- read_head_bytes(dest)
  if (grepl("^\\s*(<!DOCTYPE|<html|<HTML)", head_bytes, useBytes = TRUE) ||
      grepl("SAS Output", head_bytes, fixed = TRUE, useBytes = TRUE)) {
    msg <- tryCatch({
      html <- rvest::read_html(dest)
      txt <- rvest::html_text2(html)
      txt <- trimws(gsub("\\s+", " ", txt))
      hit <- stringr::str_extract(txt, "[^.]*not available[^.]*\\.")
      hit %||% NA_character_
    }, error = function(e) NA_character_)
    unlink(dest)
    unlink(sidecar_path(dest))
    stop(
      "TEA returned a report page instead of data for ",
      sprintf("year=%d, level=%s, dataset=%s.", row$year, row$level,
              row$dataset %||% "<none>"),
      if (!is.na(msg)) paste0("\nTEA says: ", msg),
      call. = FALSE
    )
  }
  invisible(TRUE)
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

tapr_html_report_url <- function(year, level, geography,
                                 prgopt = "reports/tapr/student.sas") {
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
    "&prgopt=", utils::URLencode(prgopt, reserved = TRUE)
  )
}

tapr_html_report_filename <- function(level, geography, page_source = "student") {
  id <- gsub("[^A-Za-z0-9_-]+", "_", as.character(geography))
  page_source <- gsub("[^A-Za-z0-9_-]+", "_", as.character(page_source))
  sprintf("tapr_%s_%s_%s.html", level, id, page_source)
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
  # TEA prefixes identifiers with an apostrophe in data files so
  # spreadsheets keep leading zeros; compare without it.
  strip_quote <- function(x) sub("^'", "", trimws(as.character(x)))
  df[strip_quote(df[[col]]) %in% strip_quote(ids), , drop = FALSE]
}
