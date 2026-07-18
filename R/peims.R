#' Download PEIMS financial data (budget or actual)
#'
#' Downloads one of TEA's PEIMS "single file" financial data downloads:
#' fund/function/object-level budget or actual financial data for all
#' Texas districts or all charter schools in one school year. These are
#' statewide bulk files (district actual files run to several million
#' rows), not per-campus reports.
#'
#' @section Coverage:
#' School years 1999-2000 (requested as ending year 2000) through the
#' present. Actual data posts roughly a year after the fiscal year ends;
#' budget data for the upcoming school year posts before it starts.
#'
#' @section Granularity and labels:
#' Rows are at the district x fund x function x object x fin-unit x
#' program-intent grain; `fin_unit` identifies the campus or
#' organization unit within the district. The raw files carry only
#' codes. With `labels = TRUE` (the default) the fund, function,
#' object, and program-intent code tables from TEA's companion
#' "multiple file" budget archive are joined in as `*_label` columns,
#' along with district and campus names where TEA publishes them. If
#' the code tables cannot be fetched, the data is returned with codes
#' only, with a warning.
#'
#' Charter files use TEA's nonprofit chart of accounts; their asset
#' (fund), function, object, and program-intent codes are normalized
#' into the same `fund_code`, `function_code`, `object_code`, and
#' `program_intent_code` columns.
#'
#' No FERPA masking applies to this source: values are dollar amounts,
#' not student counts.
#'
#' @inheritParams txs_get_tapr_file
#' @param basis `"actual"` (audited actuals) or `"budget"` (adopted
#'   budgets).
#' @param type `"district"` (traditional districts) or `"charter"`
#'   (open-enrollment charter schools).
#' @param labels If `TRUE`, join human-readable labels for the
#'   fund/function/object/program-intent codes, plus district and
#'   campus names where available.
#' @param output `"tidy"` (typed, padded, labeled) or `"raw"`
#'   (all-character columns exactly as published).
#' @param db Optional DuckDB file path or DBI connection. If supplied,
#'   the result is also written via [txs_write_peims_db()].
#' @param timeout Seconds; default 300 (district files are tens of MB).
#' @return A tibble with a `txschools` attribute. Tidy columns:
#'   `district`, `district_name`*, `fin_unit`, `campus_name`*, `year`,
#'   `school_year`, `basis`, `type`, `fund_code`, `fund_label`*,
#'   `function_code`, `function_label`*, `object_code`,
#'   `object_label`*, `program_intent_code`, `program_intent_label`*,
#'   `amount`, `fiscal_year`, `updated` (columns marked * appear only
#'   when `labels = TRUE` succeeds and TEA publishes the table).
#' @examples
#' \dontrun{
#' act <- txs_get_peims_finance(2024, "actual", "district")
#' txs_get_peims_finance(2024, "budget", "charter", db = "peims.duckdb")
#' }
#' @export
txs_get_peims_finance <- function(year,
                                  basis = c("actual", "budget"),
                                  type = c("district", "charter"),
                                  labels = TRUE,
                                  cache = TRUE,
                                  refresh = FALSE,
                                  output = c("tidy", "raw"),
                                  keep_raw = FALSE,
                                  db = NULL,
                                  timeout = 300,
                                  verbose = TRUE) {
  basis  <- match.arg(basis)
  type   <- match.arg(type)
  output <- match.arg(output)
  year   <- normalize_year(year, source = "peims")
  cache  <- isTRUE(cache)

  downloads <- if (cache) {
    txs_list_downloads(year, source = "peims", refresh = refresh)
  } else {
    with_temporary_cache_dir(
      txs_list_downloads(year, source = "peims", refresh = refresh)
    )
  }
  hits <- downloads[
    downloads$level == type & downloads$data_type == basis, , drop = FALSE
  ]
  if (!nrow(hits)) {
    available <- unique(sprintf(
      "%s %s", downloads$level, downloads$data_type
    ))
    stop(
      sprintf(
        "No PEIMS %s %s file is published for year=%d (%s).\n",
        type, basis, year, year_label(year)
      ),
      if (length(available)) {
        paste0("Available: ", paste(sort(available), collapse = ", "))
      } else {
        "No PEIMS files were found for that year."
      },
      call. = FALSE
    )
  }
  hits <- hits[1L, , drop = FALSE]

  url <- hits$url
  filename <- download_filename(hits)
  dest <- cache_path("peims", year, type, basis, file = filename)
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
      url, dest, timeout = timeout, method = hits$method %||% "get"
    )
    check_peims_data_response(dest, url)
    meta <- list(
      source       = "peims",
      year         = year,
      school_year  = year_label(year),
      level        = type,
      data_type    = basis,
      dataset      = NA_character_,
      file_format  = hits$file_format,
      source_url   = url,
      method       = hits$method,
      retrieved_at = info$retrieved_at,
      sha256       = info$sha256,
      size_bytes   = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  df_raw <- read_peims_file(dest)

  out <- switch(
    output,
    raw  = df_raw,
    tidy = peims_tidy(
      df_raw, year = year, basis = basis, type = type, labels = labels,
      cache = cache, refresh = refresh, timeout = timeout, verbose = verbose
    )
  )
  attr(out, "txschools") <- list(
    source = "peims", year = year, school_year = year_label(year),
    level = type, data_type = basis, basis = basis, type = type,
    dataset = NA_character_, file_format = hits$file_format,
    source_url = url, retrieved_at = meta$retrieved_at,
    sha256 = meta$sha256, size_bytes = meta$size_bytes,
    cache_path = dest, used_cache = used_cache
  )
  if (isTRUE(keep_raw) && output != "raw") attr(out, "raw") <- df_raw

  if (!is.null(db)) txs_write_peims_db(out, db = db, overwrite = TRUE)
  out
}

# TEA serves these as direct files; an HTML body means an error or
# landing page ended up on disk. Some downloads arrive through opaque
# redirect URLs, so the on-disk name can't be trusted either way.
# Inspects raw bytes: the file is usually a zip, which is not valid
# text in any encoding.
check_peims_data_response <- function(dest, url) {
  bytes <- readBin(dest, "raw", n = 64L)
  bytes <- bytes[!bytes %in% as.raw(c(0x09, 0x0a, 0x0d, 0x20))]
  if (length(bytes) && bytes[1] == as.raw(0x3c)) {  # "<"
    unlink(dest)
    stop(
      "TEA returned an HTML page instead of a data file for:\n  ", url,
      "\nThe file may have moved; try `refresh = TRUE`.",
      call. = FALSE
    )
  }
  invisible(dest)
}

# Read a PEIMS single-file download as all-character columns. Files
# fetched through redirect URLs may be zips regardless of the name the
# cache gave them, so sniff the magic bytes rather than the extension.
read_peims_file <- function(path) {
  if (peims_is_zip(path)) {
    return(read_peims_file(unzip_one(path)))
  }
  read_tapr_csv(path)
}

peims_is_zip <- function(path) {
  identical(
    readBin(path, "raw", n = 4L),
    as.raw(c(0x50, 0x4b, 0x03, 0x04))
  )
}

# Column-name aliases across eras and file types. District files use
# FUND/FUNCTION/OBJECT/PROGRAM_INTENT; charter files use TEA's
# nonprofit chart of accounts (CS_NONPROF_*). Both normalize to the
# same tidy vocabulary.
peims_column_aliases <- c(
  district         = "district",
  fund             = "fund_code",
  cs_nonprof_asset = "fund_code",
  "function"       = "function_code",
  cs_nonprof_func  = "function_code",
  object           = "object_code",
  cs_nonprof_obj   = "object_code",
  program_intent   = "program_intent_code",
  cs_nonprof_pgmin = "program_intent_code",
  fin_unit         = "fin_unit",
  fundyear         = "fiscal_year",
  fiscalyr         = "fiscal_year",
  budgamt          = "amount",
  actamt           = "amount",
  dtupdate         = "updated"
)

peims_code_widths <- c(
  district = 6L, fund_code = 3L, function_code = 2L, object_code = 4L,
  program_intent_code = 2L, fin_unit = 3L
)

peims_tidy <- function(df_raw, year, basis, type, labels,
                       cache, refresh, timeout, verbose) {
  out <- df_raw
  nm <- tolower(names(out))
  hit <- nm %in% names(peims_column_aliases)
  nm[hit] <- peims_column_aliases[nm[hit]]
  names(out) <- nm

  for (col in intersect(names(peims_code_widths), names(out))) {
    out[[col]] <- stringr::str_pad(
      trimws(out[[col]]), peims_code_widths[[col]], pad = "0"
    )
  }
  if ("amount" %in% names(out)) {
    out$amount <- readr::parse_number(out$amount)
  }
  if ("fiscal_year" %in% names(out)) {
    out$fiscal_year <- suppressWarnings(as.integer(out$fiscal_year))
  }
  if ("updated" %in% names(out)) {
    out$updated <- peims_parse_date(out$updated)
  }
  out$year <- as.integer(year)
  out$school_year <- year_label(year)
  out$basis <- basis
  out$type <- type

  if (isTRUE(labels)) {
    codes <- peims_code_tables(
      year = year, type = type, cache = cache, refresh = refresh,
      timeout = timeout, verbose = verbose
    )
    if (is.null(codes)) {
      cli::cli_warn(c(
        "PEIMS code tables are unavailable for {year}; returning codes only.",
        i = "Re-run with `labels = FALSE` to silence this warning."
      ))
    } else {
      out <- peims_join_labels(out, codes)
    }
  }

  front <- intersect(
    c("district", "district_name", "fin_unit", "campus_name",
      "year", "school_year", "basis", "type",
      "fund_code", "fund_label", "function_code", "function_label",
      "object_code", "object_label",
      "program_intent_code", "program_intent_label",
      "amount", "fiscal_year", "updated"),
    names(out)
  )
  out[, c(front, setdiff(names(out), front)), drop = FALSE]
}

peims_join_labels <- function(out, codes) {
  join_one <- function(out, tbl, code_col, label_col) {
    if (is.null(tbl) || !code_col %in% names(out)) return(out)
    lookup <- tbl
    names(lookup) <- c(code_col, label_col)
    dplyr::left_join(out, lookup, by = code_col)
  }
  out <- join_one(out, codes$fund, "fund_code", "fund_label")
  out <- join_one(out, codes$`function`, "function_code", "function_label")
  out <- join_one(out, codes$object, "object_code", "object_label")
  out <- join_one(out, codes$program_intent, "program_intent_code",
                  "program_intent_label")
  if (!is.null(codes$district_names) && "district" %in% names(out)) {
    lookup <- codes$district_names
    names(lookup) <- c("district", "district_name")
    out <- dplyr::left_join(out, lookup, by = "district")
  }
  if (!is.null(codes$campus_names) &&
      all(c("district", "fin_unit") %in% names(out))) {
    lookup <- codes$campus_names
    names(lookup) <- c("district", "fin_unit", "campus_name")
    out <- dplyr::left_join(out, lookup, by = c("district", "fin_unit"))
  }
  out
}

# Dates like "24JAN2024", parsed without relying on the session locale.
peims_parse_date <- function(x) {
  x <- trimws(x)
  d  <- suppressWarnings(as.integer(substr(x, 1L, 2L)))
  mo <- match(
    toupper(substr(x, 3L, 5L)),
    c("JAN", "FEB", "MAR", "APR", "MAY", "JUN",
      "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")
  )
  y  <- suppressWarnings(as.integer(substr(x, 6L, 9L)))
  out <- rep(as.Date(NA), length(x))
  ok <- !is.na(d) & !is.na(mo) & !is.na(y)
  out[ok] <- as.Date(sprintf("%04d-%02d-%02d", y[ok], mo[ok], d[ok]))
  out
}

# Fetch and parse the code tables that label a year's financial data.
# They live inside TEA's budget "multiple file" archive for the same
# ending year. Returns NULL when the archive can't be fetched or
# parsed; individual tables TEA doesn't publish (e.g. district names
# before ~2020) are NULL within the list.
peims_code_tables <- function(year, type, cache, refresh, timeout, verbose) {
  tryCatch({
    url <- discover_peims_codes_url(year)
    if (is.na(url)) return(NULL)

    bn <- basename(sub("[?#].*$", "", url))
    if (!grepl("\\.zip$", bn, ignore.case = TRUE)) {
      bn <- sprintf("peims_codes_%d.zip", year)
    }
    dest <- cache_path("peims", year, "codes", "budget", file = bn)
    if (!cache) dest <- temp_download_path(bn)

    if (!(cache && !refresh && file.exists(dest))) {
      if (verbose) cli::cli_alert_info("Downloading code tables: {url}")
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      info <- http_download(url, dest, timeout = timeout, method = "get")
      check_peims_data_response(dest, url)
      if (cache) {
        write_sidecar(dest, list(
          source = "peims", year = year, school_year = year_label(year),
          level = "codes", data_type = "budget", dataset = NA_character_,
          file_format = "zip", source_url = url,
          retrieved_at = info$retrieved_at, sha256 = info$sha256,
          size_bytes = info$size_bytes, content_type = info$content_type
        ))
      }
    }

    out_dir <- paste0(dest, "-unzipped")
    if (!dir.exists(out_dir)) {
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      utils::unzip(dest, exdir = out_dir)
    }
    members <- list.files(out_dir, recursive = TRUE, full.names = TRUE)

    district_specs <- list(
      fund           = "^fund[_]?\\d*f\\.txt$",
      `function`     = "^func(tion)?[_]?\\d*f\\.txt$",
      object         = "^obj(ect)?[_]?\\d*f\\.txt$",
      program_intent = "^(program_intent|pgmin)[_]?\\d*f\\.txt$"
    )
    charter_specs <- list(
      fund           = "^(cs_nonprof_asset\\d*|caset\\d*)f\\.txt$",
      `function`     = "^(cs_nonprof_func\\d*|csfunc)f\\.txt$",
      object         = "^(cs_nonprof_obj\\d*|csobj)f\\.txt$",
      program_intent = "^(cs_nonprof_pgmin\\d*|cspgm)f\\.txt$"
    )

    find_member <- function(re) {
      hit <- members[grepl(re, tolower(basename(members)))]
      if (length(hit)) hit[1] else NULL
    }
    widths <- c(
      fund = 3L, `function` = 2L, object = 4L, program_intent = 2L
    )
    read_spec <- function(specs, key) {
      path <- find_member(specs[[key]])
      if (is.null(path)) return(NULL)
      peims_read_code_table(path, width = widths[[key]])
    }

    codes <- list()
    for (key in names(district_specs)) {
      tbl <- read_spec(district_specs, key)
      if (type == "charter") {
        # Charter files use the nonprofit chart of accounts, but also
        # book to shared codes (e.g. fund 420) that only the district
        # tables define. Charter definitions win on conflicts.
        cs <- read_spec(charter_specs, key)
        tbl <- dplyr::bind_rows(cs, tbl)
        tbl <- tbl[!duplicated(tbl$code), , drop = FALSE]
        if (!nrow(tbl)) tbl <- NULL
      }
      codes[key] <- list(tbl)
    }

    # District tables carry the name in column 2 (column 3 is a status
    # flag), unlike the code tables' short/long label pair. Charters
    # share the district-number space, so both name tables apply to
    # both types.
    district_path <- find_member("^district[_]?\\d*f\\.txt$")
    codes["district_names"] <- list(
      if (is.null(district_path)) NULL else
        peims_read_code_table(district_path, width = 6L, label_col = 2L)
    )
    campus_path <- find_member("^(fin_unit|finu)[_]?\\d*f\\.txt$")
    codes["campus_names"] <- list(
      if (is.null(campus_path)) NULL else
        peims_read_campus_table(campus_path)
    )

    if (is.null(codes$fund) && is.null(codes$`function`) &&
        is.null(codes$object)) {
      return(NULL)
    }
    codes
  }, error = function(e) NULL)
}

# Code tables are headerless quoted CSVs: code, short label, long
# label, flags... The long label (column 3) is used when present.
peims_read_code_table <- function(path, width, label_col = NULL) {
  df <- readr::read_csv(
    path, col_names = FALSE,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(), trim_ws = TRUE, progress = FALSE
  )
  if (ncol(df) < 2L || !nrow(df)) return(NULL)
  label_col <- label_col %||% if (ncol(df) >= 3L) 3L else 2L
  tibble::tibble(
    code  = stringr::str_pad(trimws(df[[1]]), width, pad = "0"),
    label = trimws(df[[label_col]])
  )
}

# FIN_UNIT tables: district, ?, fin unit, type, name, ...
peims_read_campus_table <- function(path) {
  df <- readr::read_csv(
    path, col_names = FALSE,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(), trim_ws = TRUE, progress = FALSE
  )
  if (ncol(df) < 5L || !nrow(df)) return(NULL)
  tibble::tibble(
    district = stringr::str_pad(trimws(df[[1]]), 6L, pad = "0"),
    fin_unit = stringr::str_pad(trimws(df[[3]]), 3L, pad = "0"),
    name     = trimws(df[[5]])
  )
}

#' Write PEIMS financial data to DuckDB
#'
#' Writes a tibble returned by [txs_get_peims_finance()] to a DuckDB
#' database (or any DBI connection) as a table named
#' `peims_finance_<basis>_<type>_<year>`, and appends a provenance row
#' to a `_peims_meta` table. Calling this once per year/basis/type
#' builds a multi-year database suitable for `dbplyr` aggregation.
#'
#' @param x A tibble from [txs_get_peims_finance()].
#' @param db A DuckDB file path or an existing DBI connection.
#' @param overwrite If `TRUE`, replace an existing table with the same
#'   name.
#' @return Invisibly returns `x`.
#' @examples
#' \dontrun{
#' act <- txs_get_peims_finance(2024, "actual", "district")
#' txs_write_peims_db(act, "peims.duckdb")
#' }
#' @export
txs_write_peims_db <- function(x, db, overwrite = FALSE) {
  meta <- attr(x, "txschools")
  if (!is.list(meta) || !identical(meta$source, "peims")) {
    stop("`x` must be a tibble returned by `txs_get_peims_finance()`.",
         call. = FALSE)
  }
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package `DBI` is required to write PEIMS data to a database.",
         call. = FALSE)
  }

  disconnect <- FALSE
  con <- db
  if (is.character(db) && length(db) == 1L) {
    if (!requireNamespace("duckdb", quietly = TRUE)) {
      stop("Package `duckdb` is required when `db` is a file path.",
           call. = FALSE)
    }
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db)
    disconnect <- TRUE
  }
  if (disconnect) {
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  }

  name <- sprintf(
    "peims_finance_%s_%s_%d", meta$basis, meta$type, meta$year
  )
  write_tapr_db_table(con, name, x, overwrite = overwrite)

  meta_row <- tibble::tibble(
    table       = name,
    year        = as.integer(meta$year),
    school_year = meta$school_year %||% NA_character_,
    basis       = meta$basis,
    type        = meta$type,
    source_url  = meta$source_url %||% NA_character_,
    retrieved_at = meta$retrieved_at %||% NA_character_,
    sha256      = meta$sha256 %||% NA_character_,
    written_at  = iso8601_now()
  )
  if (DBI::dbExistsTable(con, "_peims_meta")) {
    DBI::dbAppendTable(con, "_peims_meta", as.data.frame(meta_row))
  } else {
    DBI::dbWriteTable(con, "_peims_meta", as.data.frame(meta_row))
  }
  invisible(x)
}
