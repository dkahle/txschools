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
  if (!nrow(hits) && cache && !refresh) {
    downloads <- txs_list_downloads(year, source = "tapr", refresh = TRUE)
    hits <- downloads[
      downloads$level == level & downloads$data_type == "dictionary",
      , drop = FALSE
    ]
  }
  if (!nrow(hits)) {
    stop(tapr_dictionary_not_found_message(year, level, downloads),
         call. = FALSE)
  }
  hits <- hits[order(match(hits$file_format, c("xlsx", "html"))), , drop = FALSE]
  hits <- hits[1L, , drop = FALSE]

  url <- hits$url
  file_format <- hits$file_format %||% "xlsx"
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
      file_format  = file_format,
      source_url   = url,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  out <- if (identical(file_format, "html")) {
    read_tapr_html_dictionary(
      dest, page_url = url, year = year, level = level,
      cache = cache, timeout = timeout, verbose = verbose
    )
  } else {
    read_tapr_dictionary(dest, year = year, level = level)
  }
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

tapr_dictionary_not_found_message <- function(year, level, downloads) {
  dict <- downloads[downloads$data_type == "dictionary", , drop = FALSE]
  advanced <- downloads[downloads$data_type == "advanced", , drop = FALSE]
  msg <- sprintf(
    "No TAPR dictionary file found for year=%d, level=%s.",
    year, level
  )
  if (nrow(dict)) {
    levels <- paste(sort(unique(dict$level)), collapse = ", ")
    msg <- paste0(msg, "\nDictionary files were discovered for: ", levels, ".")
  } else {
    msg <- paste0(
      msg,
      "\nNo TAPR dictionary files were discovered for any level in ",
      year, "."
    )
  }
  if (nrow(advanced)) {
    msg <- paste0(
      msg,
      "\nAdvanced data files were discovered for this year; inspect ",
      "`txs_list_downloads(", year, ', "tapr", refresh = TRUE)` to see ',
      "what TEA currently publishes."
    )
  }
  paste0(
    msg,
    "\nTry `refresh = TRUE` in case a cached TEA download page is stale."
  )
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

read_tapr_html_dictionary <- function(path, page_url, year, level,
                                      cache = TRUE, timeout = 60,
                                      verbose = TRUE) {
  html_str <- read_text_file(path)
  links <- parse_tapr_html_reference_detail_links(html_str, page_url)
  links <- links[links$level == level, , drop = FALSE]
  if (!nrow(links)) {
    all_levels <- parse_tapr_html_reference_detail_links(html_str, page_url)$level
    all_levels <- sort(unique(all_levels[!is.na(all_levels)]))
    stop(
      "The TAPR HTML master reference did not include detail pages for ",
      sprintf("year=%d, level=%s.", year, level),
      if (length(all_levels)) {
        paste0("\nAvailable levels in the HTML reference: ",
               paste(all_levels, collapse = ", "), ".")
      },
      call. = FALSE
    )
  }

  rows <- lapply(seq_len(nrow(links)), function(i) {
    dataset <- links$dataset[[i]]
    filename <- paste0(tolower(dataset), ".html")
    detail_path <- if (cache) {
      cache_path("tapr", year, level, "dictionary", file = filename)
    } else {
      temp_download_path(filename)
    }

    if (cache && file.exists(detail_path)) {
      if (verbose) cli::cli_alert_info("Using cached file: {detail_path}")
    } else {
      if (verbose) cli::cli_alert_info("Downloading: {links$url[[i]]}")
      dir.create(dirname(detail_path), recursive = TRUE, showWarnings = FALSE)
      http_download(links$url[[i]], detail_path, timeout = timeout)
    }

    parse_tapr_html_dictionary_detail(
      read_text_file(detail_path),
      year = year, level = level, dataset = dataset
    )
  })
  rows <- rows[vapply(rows, nrow, integer(1)) > 0L]
  if (!length(rows)) {
    stop("TAPR HTML dictionary pages did not contain NAME/LABEL tables: ",
         page_url, call. = FALSE)
  }
  dplyr::bind_rows(rows)
}

parse_tapr_html_reference_detail_links <- function(html_str, page_url) {
  html <- read_html_tolerant(html_str)
  anchors <- rvest::html_elements(html, "a")
  hrefs <- rvest::html_attr(anchors, "href")
  labels <- trimws(rvest::html_text(anchors))
  keep <- !is.na(hrefs) &
    grepl("\\.html?(\\?|$)", hrefs, ignore.case = TRUE)
  hrefs <- hrefs[keep]; labels <- labels[keep]
  if (!length(hrefs)) {
    return(tibble::tibble(
      level = character(), dataset = character(),
      url = character(), label = character()
    ))
  }

  urls <- xml2::url_absolute(hrefs, page_url)
  paths <- vapply(
    urls,
    function(u) httr2::url_parse(u)$path %||% "",
    character(1)
  )
  stems <- toupper(tools::file_path_sans_ext(basename(paths)))
  skip <- tolower(stems) %in% c("taprref", "taprhelp", "downloaddata",
                                "downloadseldata")
  levels <- vapply(stems, tapr_reference_detail_level, character(1))
  out <- tibble::tibble(
    level = levels,
    dataset = stems,
    url = urls,
    label = labels
  )
  out <- out[!skip & !is.na(out$level), , drop = FALSE]
  out[!duplicated(out[, c("level", "dataset", "url")]), , drop = FALSE]
}

tapr_reference_detail_level <- function(stem) {
  stem <- tolower(stem)
  if (grepl("^(camp|c)", stem)) return("campus")
  if (grepl("^(district|dist|d)", stem)) return("district")
  if (grepl("^(region|regn|reg|r)", stem)) return("region")
  if (grepl("^(state|s)", stem)) return("state")
  NA_character_
}

parse_tapr_html_dictionary_detail <- function(html_str, year, level, dataset) {
  html <- read_html_tolerant(html_str)
  tables <- rvest::html_table(html, fill = TRUE)
  if (!length(tables)) {
    return(tibble::tibble(
      year = integer(), school_year = character(), level = character(),
      sheet = character(), dataset = character(), variable = character(),
      label = character()
    ))
  }
  names_upper <- lapply(tables, function(x) toupper(names(x)))
  hits <- which(vapply(
    names_upper,
    function(nm) all(c("NAME", "LABEL") %in% nm),
    logical(1)
  ))
  if (!length(hits)) {
    return(tibble::tibble(
      year = integer(), school_year = character(), level = character(),
      sheet = character(), dataset = character(), variable = character(),
      label = character()
    ))
  }
  hit <- hits[[1]]

  df <- tables[[hit]]
  names(df) <- toupper(names(df))
  variable <- as.character(df$NAME)
  label <- as.character(df$LABEL)
  keep <- !is.na(variable) & nzchar(variable) & !is.na(label)
  tibble::tibble(
    year        = as.integer(year),
    school_year = year_label(year),
    level       = level,
    sheet       = dataset,
    dataset     = dataset,
    variable    = variable[keep],
    label       = label[keep]
  )
}

read_text_file <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  readChar(con, nchars = file.info(path)$size, useBytes = TRUE)
}
