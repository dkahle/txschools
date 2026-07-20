#' Download an SRC (School Report Card) report
#'
#' TEA publishes the School Report Card as *per-campus (or district)
#' reports*, not as bulk data files. This function downloads one report
#' through TEA's public SAS-broker interface and, where TEA serves an
#' HTML report, parses it into a tidy masking-aware tibble.
#'
#' @section Coverage:
#' * **2004-2012 campus reports** are available as HTML and are parsed
#'   into a tidy long tibble.
#' * **2004-2012 district reports and all 2013-2019 reports** are
#'   published by TEA as PDF only. These are downloaded to the cache and
#'   returned as a one-row tibble describing the file (see `Value`).
#' * **2020 and later** SRC reports live at <https://txschools.gov>,
#'   which this package does not scrape.
#'
#' @inheritParams txs_get_tapr_file
#' @param level `"campus"` or `"district"`.
#' @param geography A single campus (9-digit) or district (6-digit)
#'   number, quoted to preserve leading zeros.
#' @param format `"auto"` (HTML when TEA offers it, else PDF), `"html"`,
#'   or `"pdf"`.
#' @param output For HTML reports: `"tidy"` (long, masking-aware) or
#'   `"raw"` (the report's text lines, one row per line).
#' @return For HTML reports, a tibble with columns `year`,
#'   `school_year`, `level`, `geography`, `school_name`,
#'   `district_name`, `page`, `section`, `measure`, `row_label`,
#'   `column`, `value`, `value_num`, `masked`, `mask_code`. For PDF
#'   reports, a one-row tibble with the cached file's path and
#'   provenance. Both carry a `txschools` attribute.
#' @examples
#' \dontrun{
#' src_2011 <- txs_get_src(2011, "campus", "161920102")
#' }
#' @export
txs_get_src <- function(year,
                        level = c("campus", "district"),
                        geography = NULL,
                        format = c("auto", "html", "pdf"),
                        cache = TRUE,
                        refresh = FALSE,
                        output = c("tidy", "raw"),
                        timeout = 60,
                        verbose = TRUE) {
  level  <- match.arg(level)
  format <- match.arg(format)
  output <- match.arg(output)
  cache  <- isTRUE(cache)

  if (is.numeric(year) && length(year) == 1L && !is.na(year) &&
      year > TXS_LAST_SRC_YEAR) {
    stop(
      sprintf("SRC reports after %d are published at https://txschools.gov, ",
              TXS_LAST_SRC_YEAR),
      "which txschools does not scrape.",
      call. = FALSE
    )
  }
  year <- normalize_year(year, source = "src")

  if (is.null(geography) || length(geography) != 1L ||
      is.na(geography) || !nzchar(as.character(geography))) {
    stop(
      "`geography` must be a single campus (9-digit) or district ",
      "(6-digit) number, quoted to preserve leading zeros.",
      call. = FALSE
    )
  }
  geography <- as.character(geography)

  html_available <- identical(level, "campus") && year <= TXS_LAST_SRC_HTML_YEAR
  if (identical(format, "auto")) {
    format <- if (html_available) "html" else "pdf"
  }
  if (identical(format, "html") && !html_available) {
    stop(
      "TEA serves SRC ", level, " reports for ", year, " as PDF only. ",
      "Use `format = \"pdf\"` (HTML campus reports exist for 2004-2012).",
      call. = FALSE
    )
  }

  req <- src_report_request(year, level, geography, format)
  filename <- sprintf("src_%s_%s_%d.%s", level,
                      gsub("[^A-Za-z0-9_-]+", "_", geography), year, format)
  dest <- cache_path("src", year, level, "report", file = filename)
  if (!cache) dest <- temp_download_path(filename)

  used_cache <- FALSE
  if (cache && !refresh && file.exists(dest)) {
    if (verbose) cli::cli_alert_info("Using cached file: {dest}")
    used_cache <- TRUE
    meta <- read_sidecar(dest) %||% list(
      source_url = req$url, retrieved_at = NA_character_,
      sha256 = sha256_file(dest), size_bytes = file.size(dest),
      content_type = NA_character_
    )
  } else {
    if (verbose) cli::cli_alert_info("Downloading SRC {level} report: {req$url}")
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    info <- http_download(
      req$url, dest, timeout = timeout,
      method = req$method, params = req$params
    )
    src_check_response(dest, format, year, level, geography)
    meta <- list(
      source       = "src",
      year         = year,
      school_year  = year_label(year),
      level        = level,
      geography    = geography,
      data_type    = "report",
      file_format  = format,
      source_url   = req$url,
      method       = req$method,
      params       = req$params,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  meta_common <- list(
    source       = "src",
    year         = year,
    school_year  = year_label(year),
    level        = level,
    geography    = geography,
    file_format  = format,
    source_url   = req$url,
    retrieved_at = meta$retrieved_at,
    sha256       = meta$sha256,
    cache_path   = dest,
    used_cache   = used_cache,
    masking_values = mask_codes()
  )

  if (identical(format, "pdf")) {
    out <- tibble::tibble(
      year         = as.integer(year),
      school_year  = year_label(year),
      level        = level,
      geography    = geography,
      file_format  = "pdf",
      path         = dest,
      source_url   = req$url,
      retrieved_at = meta$retrieved_at %||% NA_character_,
      sha256       = meta$sha256 %||% NA_character_
    )
    attr(out, "txschools") <- meta_common
    if (verbose) {
      cli::cli_alert_success("SRC PDF report cached at {dest}")
    }
    return(out)
  }

  parsed <- src_parse_html_report(dest, year = year, level = level,
                                  geography = geography)
  out <- if (identical(output, "raw")) {
    tibble::tibble(line = parsed$lines)
  } else {
    parsed$data
  }
  attr(out, "txschools") <- c(meta_common, list(header = parsed$header))
  out
}

#' Open a campus or district's Texas School Report Card
#'
#' Since 2020, TEA publishes School Report Cards exclusively at
#' <https://txschools.gov> -- a JavaScript application this package
#' cannot scrape (see [txs_get_src()] for the parsed 2004-2019
#' archive). This function is the complement for anything
#' [txs_get_src()] cannot reach: it does not download or parse
#' anything, it just launches the right page in a browser.
#'
#' @param geography A single campus (9-digit) or district (6-digit)
#'   number, quoted to preserve leading zeros.
#' @param level `"campus"` or `"district"`.
#' @param tab Which tab of the report card to land on -- TEA-defined,
#'   e.g. `"overview"`, `"academic"`, `"stakeholder-and-community-input"`,
#'   or (district level) `"schools"` to list its campuses.
#' @param browse If `TRUE` (the default), open the URL with
#'   [utils::browseURL()]. Set `FALSE` to only build the URL, e.g. for
#'   scripting or testing.
#' @return Invisibly, the URL.
#' @examples
#' \dontrun{
#' txs_open_src("161920102")                     # China Spring Elementary
#' txs_open_src("161920", level = "district")     # China Spring ISD
#' }
#' @export
txs_open_src <- function(geography,
                         level = c("campus", "district"),
                         tab = "overview",
                         browse = TRUE) {
  level <- match.arg(level)
  if (is.null(geography) || length(geography) != 1L ||
      is.na(geography) || !nzchar(as.character(geography))) {
    stop(
      "`geography` must be a single campus (9-digit) or district ",
      "(6-digit) number, quoted to preserve leading zeros.",
      call. = FALSE
    )
  }
  geography <- as.character(geography)

  view <- if (identical(level, "campus")) "school" else "district"
  url <- sprintf(
    "%s/?view=%s&id=%s&tab=%s&lng=en",
    TXS_LANDING_SRC, view, geography, utils::URLencode(tab, reserved = TRUE)
  )
  if (isTRUE(browse)) utils::browseURL(url)
  invisible(url)
}

# Build the broker request for one SRC report. Parameter sets verified
# against TEA's live search forms (2011 and 2019 eras).
src_report_request <- function(year, level, geography, format) {
  if (year <= TXS_LAST_SRC_HTML_YEAR) {
    params <- list(
      `_service` = "marykay",
      `_program` = "perfrept.perfmast.sas",
      `_debug`   = "0",
      prgopt     = sprintf("%d/src/alltypec.sas", year),
      year4      = as.character(year),
      year2      = sprintf("%02d", year %% 100L),
      topic      = "src",
      gifname    = sprintf("g_src%d", year),
      title      = "School Report Card",
      ptype      = toupper(format),
      level      = if (identical(level, "campus")) "Campus" else "District",
      sublevel   = if (identical(level, "campus")) "camp" else "dist",
      search     = if (identical(level, "campus")) "campnum" else "distnum",
      namenum    = geography
    )
    list(url = catalog_broker_url(), method = "post",
         params = encode_query_params(params))
  } else {
    params <- list(
      `_service` = "marykay",
      `_program` = "perfrept.perfmast.sas",
      `_debug`   = "0",
      prgopt     = sprintf("%d/src/src.sas", year),
      cyr        = as.character(year)
    )
    params$level <- level
    params[[level]] <- geography
    list(url = catalog_broker_url(), method = "get",
         params = encode_query_params(params))
  }
}

# Validate that TEA returned what we asked for (PDF magic bytes, or an
# HTML report that actually contains a report body).
src_check_response <- function(dest, format, year, level, geography) {
  head_bytes <- read_head_bytes(dest)
  bad <- FALSE
  if (identical(format, "pdf")) {
    bad <- !grepl("^%PDF", head_bytes, useBytes = TRUE)
  } else {
    body <- tryCatch(
      rvest::html_text2(rvest::read_html(dest)),
      error = function(e) ""
    )
    bad <- !grepl("School Report Card", body, fixed = TRUE) ||
      grepl("Error reading SAS output", head_bytes, fixed = TRUE,
            useBytes = TRUE)
  }
  if (bad) {
    unlink(dest)
    unlink(sidecar_path(dest))
    stop(
      sprintf(
        "TEA did not return an SRC %s report for year=%d, level=%s, geography=%s. ",
        toupper(format), year, level, geography
      ),
      "Check the identifier (campus numbers are 9 digits, districts 6).",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# --- HTML-era report parsing -------------------------------------------------

# SRC HTML reports (2004-2012, campus) are one <pre> block of
# fixed-width SAS listing output. Pages repeat a header (school
# name/number, district, ratings) and carry one column-header block
# above the data lines.
src_parse_html_report <- function(path, year, level, geography) {
  html <- rvest::read_html(path)
  pre <- rvest::html_elements(html, "pre")
  if (!length(pre)) {
    stop("SRC report did not contain the expected report body: ", path,
         call. = FALSE)
  }
  text <- paste(vapply(pre, rvest::html_text, character(1)), collapse = "\n")
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]

  header <- src_parse_header(lines)
  pages <- src_split_pages(lines)
  data <- dplyr::bind_rows(lapply(seq_along(pages), function(i) {
    src_parse_page(pages[[i]], page = i)
  }))

  if (nrow(data)) {
    ms <- mask_strip(data$value)
    data$value_num <- ms$value_num
    data$masked <- ms$masked
    data$mask_code <- ms$mask_code
    data <- tibble::tibble(
      year = as.integer(year),
      school_year = year_label(year),
      level = level,
      geography = as.character(geography),
      school_name = header$school_name %||% NA_character_,
      district_name = header$district_name %||% NA_character_,
      data
    )
  }
  list(data = data, header = header, lines = lines)
}

src_parse_header <- function(lines) {
  grab <- function(pattern) {
    hit <- stringr::str_match(lines, pattern)[, 2]
    hit <- trimws(hit[!is.na(hit)])
    if (length(hit)) hit[[1]] else NA_character_
  }
  list(
    school_name    = grab("School Name:\\s*(.*?)\\s{2,}"),
    school_number  = grab("School Number:\\s*(\\d{9})"),
    district_name  = grab("District Name:\\s*(.*?)(?:\\s{2,}|$)"),
    enrollment     = grab("School Enrollment:\\s*([\\d,]+)"),
    grade_span     = grab("Grade Span:\\s*(\\S.*?)(?:\\s{2,}|\\s*$)"),
    school_type    = grab("School Type:\\s*(.*?)(?:\\s{2,}|\\s*$)"),
    school_rating  = grab("School Accountability Rating:\\s*(.*?)(?:\\s{2,}|\\s*$)"),
    district_rating = grab("District Accountability Rating:\\s*(.*?)(?:\\s{2,}|\\s*$)")
  )
}

src_split_pages <- function(lines) {
  page_starts <- grep("T E X A S\\s+E D U C A T I O N\\s+A G E N C Y", lines)
  if (!length(page_starts)) return(list(lines))
  bounds <- c(page_starts, length(lines) + 1L)
  lapply(seq_along(page_starts), function(i) {
    lines[bounds[i]:(bounds[i + 1L] - 1L)]
  })
}

# A "value token" is what SRC prints in data cells: numbers (optionally
# %, $, commas, decimals), or the mask/absence markers.
src_is_value_token <- function(tok) {
  grepl("^[<>]?\\s*-?[$]?[0-9][0-9,.]*%?$", tok) |
    tok %in% c("*", "-", "n/a", "N/A", "?")
}

src_parse_page <- function(page_lines, page) {
  # Drop the repeated per-page header: everything through the last
  # header-metadata line before the column-header block.
  is_meta <- grepl(
    "School Name:|School Number:|District Name:|School Enrollment:|Grade Span:|School Type:|Accountability Rating:|Gold Performance|E D U C A T I O N|School Report Card|Questions\\?|complete report",
    page_lines
  )
  body <- page_lines
  body[is_meta] <- ""

  is_data <- vapply(body, src_line_is_data, logical(1))
  if (!any(is_data)) return(tibble::tibble())

  # Column-header blocks: SRC column headers are deeply indented (they
  # sit above the value columns, to the right of the label margin),
  # while section headings and row labels hug the left margin. A page
  # can hold several tables, each introduced by its own header block;
  # parse each table segment with its own columns.
  indent <- nchar(body) - nchar(sub("^\\s*", "", body))
  deep <- which(nzchar(trimws(body)) & indent >= 20L & !is_data)
  if (!length(deep)) return(tibble::tibble())
  run_id <- cumsum(c(1L, diff(deep) != 1L))
  runs <- split(deep, run_id)

  segments <- list()
  for (k in seq_along(runs)) {
    hdr <- runs[[k]]
    seg_start <- max(hdr) + 1L
    seg_end <- if (k < length(runs)) min(runs[[k + 1L]]) - 1L else length(body)
    if (seg_start > seg_end) next
    seg_data <- which(is_data[seg_start:seg_end]) + seg_start - 1L
    if (!length(seg_data)) next
    segments[[length(segments) + 1L]] <- list(
      header = body[hdr], from = seg_start, to = seg_end
    )
  }
  if (!length(segments)) return(tibble::tibble())

  out <- list()
  for (seg in segments) {
    seg_lines <- body[seg$from:seg$to]
    seg_is_data <- is_data[seg$from:seg$to]
    cols <- src_header_columns(seg$header, seg_lines[seg_is_data])
    if (is.null(cols)) next

    section <- NA_character_
    measure <- NA_character_
    last_heading_i <- -10L
    for (i in seq_along(seg_lines)) {
      line <- seg_lines[[i]]
      if (!nzchar(trimws(line))) next
      if (grepl("^\\s*_+\\s*$", line)) next
      if (seg_is_data[[i]]) {
        parsed <- src_slice_data_line(line, cols)
        label <- parsed$label
        trailing_year <- stringr::str_match(
          label, "^(.*?)\\s+((?:19|20)\\d{2}(?:[\u2013-]\\d{2})?)$"
        )
        if (grepl("^(19|20)\\d{2}([\u2013-]\\d{2})?$", label)) {
          # Continuation row for another year of the same measure.
          row_label <- label
        } else if (!is.na(trailing_year[1, 1])) {
          measure <- trimws(trailing_year[1, 2])
          row_label <- trailing_year[1, 3]
        } else {
          measure <- label
          row_label <- label
        }
        for (j in seq_along(cols$names)) {
          val <- parsed$values[[j]]
          if (!nzchar(val)) next
          out[[length(out) + 1L]] <- tibble::tibble(
            page = as.integer(page),
            section = section,
            measure = measure,
            row_label = row_label,
            column = cols$names[[j]],
            value = val
          )
        }
      } else {
        heading <- trimws(gsub("\\s+", " ", line))
        if (nzchar(heading)) {
          if (!is.na(section) && i == last_heading_i + 1L) {
            # Continuation of a multi-line heading.
            section <- paste(section, heading)
          } else {
            section <- heading
            measure <- NA_character_
          }
          last_heading_i <- i
        }
      }
    }
  }
  dplyr::bind_rows(out)
}

# A data line has at least two value tokens among its 2+-space-separated
# fields.
src_line_is_data <- function(line) {
  toks <- strsplit(trimws(line), "\\s{2,}")[[1]]
  toks <- toks[nzchar(toks)]
  if (length(toks) < 2L) return(FALSE)
  sum(src_is_value_token(toks)) >= 2L
}

# Derive column spans from where value tokens actually sit on the data
# lines (values are separated by 2+ spaces, so their char-position
# occupancy yields clean per-column runs), then name each span with the
# header words whose positions overlap it.
src_header_columns <- function(header_lines, data_lines) {
  header_lines <- header_lines[nzchar(trimws(header_lines))]
  if (!length(header_lines) || !length(data_lines)) return(NULL)
  width <- max(nchar(c(header_lines, data_lines)))

  occupied <- rep(FALSE, width)
  for (line in data_lines) {
    for (tok in src_line_tokens(line)) {
      if (src_is_value_token(tok$text)) {
        occupied[tok$start:tok$end] <- TRUE
      }
    }
  }
  runs <- rle(occupied)
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1L
  spans <- data.frame(start = starts[runs$values], end = ends[runs$values])
  # Value spans left of the header region are row labels that happen to
  # look numeric (e.g. year sub-rows); the first header token marks the
  # start of the value region.
  hdr_min <- min(vapply(header_lines, function(l) {
    nchar(l) - nchar(sub("^\\s*", "", l)) + 1L
  }, integer(1)))
  spans <- spans[spans$end >= hdr_min, , drop = FALSE]
  if (nrow(spans) < 2L) return(NULL)

  # Assign each header *word* to the single span it overlaps most (ties
  # broken by distance between centers), then build names in reading
  # order. Word-level assignment matters because adjacent column
  # headers can be separated by a single space ("Students) American").
  assigned <- vector("list", nrow(spans))
  for (line in header_lines) {
    for (tok in src_word_tokens(line)) {
      overlap <- pmax(
        0L,
        pmin(tok$end, spans$end) - pmax(tok$start, spans$start) + 1L
      )
      tok_center <- (tok$start + tok$end) / 2
      span_center <- (spans$start + spans$end) / 2
      score <- overlap - abs(tok_center - span_center) / (2 * width)
      best <- which.max(score)
      if (overlap[best] > 0L ||
          abs(tok_center - span_center[best]) <= 6) {
        assigned[[best]] <- c(assigned[[best]], tok$text)
      }
    }
  }
  names_ <- vapply(seq_len(nrow(spans)), function(i) {
    trimws(gsub("\\s+", " ", paste(assigned[[i]], collapse = " ")))
  }, character(1))

  # Cut points midway between adjacent spans; the label region is
  # everything left of the first cut.
  cuts <- integer(nrow(spans) - 1L)
  for (i in seq_len(nrow(spans) - 1L)) {
    cuts[i] <- (spans$end[i] + spans$start[i + 1L]) %/% 2L
  }
  label_cut <- max(1L, spans$start[1L] - 2L)
  list(names = names_, cuts = c(label_cut, cuts))
}

# Tokenize a fixed-width line into (text, start, end) fields split on
# 2+ spaces.
src_line_tokens <- function(line) {
  src_tokens_from_regex(line, "\\S+(?:\\s\\S+)*")
}

# Tokenize into single words (any whitespace splits).
src_word_tokens <- function(line) {
  src_tokens_from_regex(line, "\\S+")
}

src_tokens_from_regex <- function(line, pattern) {
  m <- gregexpr(pattern, line)[[1]]
  if (identical(as.integer(m[1]), -1L)) return(list())
  lens <- attr(m, "match.length")
  lapply(seq_along(m), function(i) {
    list(
      text = substr(line, m[i], m[i] + lens[i] - 1L),
      start = as.integer(m[i]),
      end = as.integer(m[i] + lens[i] - 1L)
    )
  })
}

src_slice_data_line <- function(line, cols) {
  width <- max(nchar(line), max(cols$cuts) + 1L)
  line <- formatC(line, width = -width)
  cuts <- c(cols$cuts, width)
  label <- trimws(substr(line, 1L, cols$cuts[1L]))
  values <- vapply(seq_along(cols$names), function(i) {
    trimws(substr(line, cuts[i] + 1L, cuts[i + 1L]))
  }, character(1))
  list(label = trimws(gsub("\\s+", " ", label)), values = values)
}