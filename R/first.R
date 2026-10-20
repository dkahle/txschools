#' Download TEA's FIRST financial integrity ratings
#'
#' Returns the Financial Integrity Rating System of Texas (FIRST)
#' ratings TEA assigns every school district (School FIRST) and
#' open-enrollment charter (Charter FIRST): one row per district or
#' charter per rating year, with its pass/fail status, rating, letter
#' grade, and score. TEA publishes these only through two public search
#' apps, not as files; each statewide workbook is fetched from those
#' apps on demand and cached like any other download.
#'
#' @section Years:
#' `years` are ending *rating* years, matching TEA's labels: `2026` means
#' the 2025-26 FIRST ratings, which TEA computes from fiscal-year 2025
#' (2024-25 school year) financial data. The `fiscal_year` column
#' (`year - 1`) joins the rated data to PEIMS actuals, e.g.
#' `txs_get_peims_finance(2025, "actual")`.
#'
#' @section Coverage:
#' School FIRST covers 2002-03 onward and Charter FIRST 2011-12 onward.
#' Since 2017-18 TEA rates university charters pass/fail in a separate
#' list; those rows have `type = "charter"`, `university_charter =
#' TRUE`, and no score. TEA's public site has no separate university
#' list before 2017-18.
#'
#' The rating system changed over time, so compare `rating` and `score`
#' within an era:
#' * 2002-03 to 2013-14: "Superior Achievement", "Above Standard
#'   Achievement", "Standard Achievement", "Substandard Achievement"
#'   (plus "Suspended: ..." and, for charters, "Undetermined"); scores
#'   out of 65 to 85 points depending on the year.
#' * 2014-15: pass/fail only ("Pass" or "Substandard Achievement"),
#'   scored out of 30.
#' * 2015-16 onward: letter grades out of 100 points, "A = Superior"
#'   through "F = Substandard Achievement" (worded "A = Superior
#'   Achievement" from 2020-21; Charter FIRST writes "A - ..."). The
#'   `grade` column holds the letter for these years and is `NA` before.
#'
#' @section Preliminary and final ratings:
#' TEA posts preliminary ratings in August and final ratings, after
#' appeals, by mid-November. Charter FIRST labels its workbooks
#' accordingly, but School FIRST labels every workbook "Final". The
#' `release` column therefore follows TEA's label for charters and
#' marks a district workbook `"preliminary"` when it was downloaded
#' before December 1 of the rating year. Cached copies are never
#' replaced silently: once finals post, re-run with `refresh = TRUE`
#' (the function reminds you when a cached copy predates them).
#'
#' @section How it is fetched:
#' Each (rating year, list) workbook takes one short session against
#' TEA's search app, at one request per second: three requests for the
#' district or charter list, four for the university-charter list. The
#' full history, `txs_get_first(2003:2026)`, is about 150 requests on
#' first use and free afterwards.
#'
#' @param years Integer vector of ending rating years (2026 means the
#'   2025-26 ratings). Required.
#' @param type `"district"` (School FIRST), `"charter"` (Charter FIRST,
#'   including university charters), or both (the default).
#' @param output `"tidy"` (one typed row per district or charter and
#'   rating year) or `"raw"` (TEA's columns as published, all
#'   character, after `year`, `list`, and `tea_title` columns).
#' @inheritParams txs_get_peims_finance
#' @param timeout Seconds per request; default 60.
#' @return A tibble with columns `year`, `school_year`, `fiscal_year`,
#'   `type` (`"district"` or `"charter"`), `university_charter`,
#'   `district` (6-digit district number, zero-padded string),
#'   `district_name`, `region` (2-digit ESC region), `status`,
#'   `rating`, `grade`, `score`, `release` (`"preliminary"` or
#'   `"final"`), and `last_updated` (Date), plus a `txschools`
#'   attribute recording each workbook's provenance.
#' @examples
#' \dontrun{
#' first <- txs_get_first(2026)
#' txs_get_first(2020:2026, type = "district") |>
#'   dplyr::filter(district == "161920")
#' }
#' @export
txs_get_first <- function(years,
                          type = c("district", "charter"),
                          cache = TRUE,
                          refresh = FALSE,
                          output = c("tidy", "raw"),
                          timeout = 60,
                          verbose = TRUE) {
  if (missing(years) || !length(years)) {
    stop(
      "`years` is required: ending rating years, e.g. txs_get_first(2026) ",
      "for the 2025-26 ratings. The full history (2003:2026) is about ",
      "150 polite requests on first use, then cached.",
      call. = FALSE
    )
  }
  type <- match.arg(type, several.ok = TRUE)
  output <- match.arg(output)
  cache <- isTRUE(cache)
  years <- vapply(years, normalize_year, integer(1), source = "first")
  years <- sort(unique(years))

  lists <- c(
    if ("district" %in% type) "district",
    if ("charter" %in% type) c("charter", "university_charter")
  )
  parts <- list()
  for (l in lists) {
    start <- TXS_FIRST_RATING_START[[l]]
    early <- years[years < start]
    if (verbose && length(early)) {
      cli::cli_alert_info(paste0(
        "{first_list_label(l)} ratings begin with {year_label(start)}; ",
        "skipping {early}."
      ))
    }
    for (y in years[years >= start]) {
      got <- tryCatch(
        first_get_file(l, y, cache = cache, refresh = refresh,
                       timeout = timeout, verbose = verbose),
        error = function(e) {
          cli::cli_warn(paste0(
            "Skipping {first_list_label(l)} {year_label(y)}: ",
            "{conditionMessage(e)}"
          ))
          NULL
        }
      )
      if (!is.null(got)) {
        parts[[length(parts) + 1L]] <- c(got, list(list = l, year = y))
      }
    }
  }
  if (!length(parts)) {
    stop("No FIRST ratings could be retrieved for the requested years.",
         call. = FALSE)
  }
  if (verbose) first_note_release(parts)

  if (output == "raw") {
    out <- dplyr::bind_rows(lapply(parts, function(p) {
      tibble::add_column(p$wb$data, year = p$year, list = p$list,
                         tea_title = p$wb$title, .before = 1)
    }))
  } else {
    out <- dplyr::bind_rows(lapply(parts, function(p) {
      first_tidy(p$wb$data, p$list, p$year, p$meta)
    }))
    out <- dplyr::arrange(out, .data$year, .data$district,
                          .data$university_charter)
    dupes <- duplicated(out[c("year", "district")])
    if (any(dupes)) {
      cli::cli_warn(paste0(
        "TEA lists {sum(dupes)} district{?s} more than once in a rating ",
        "year; kept as published."
      ))
    }
  }

  files <- lapply(parts, `[[`, "meta")
  retrieved <- stats::na.omit(vapply(
    files, function(m) m$retrieved_at %||% NA_character_, character(1)
  ))
  attr(out, "txschools") <- list(
    source = "first", years = years, types = type,
    level = "district", data_type = "ratings",
    files = files,
    retrieved_at = if (length(retrieved)) max(retrieved) else NA_character_
  )
  out
}

# --- Downloads ---------------------------------------------------------------

first_list_label <- function(list) {
  switch(list,
    district           = "School FIRST",
    charter            = "Charter FIRST",
    university_charter = "Charter FIRST (university charters)"
  )
}

# One cached workbook per (rating year, list). A cache hit needs the
# sidecar too: the sidecar is written last, so a file without one is an
# interrupted download. Returns list(path, meta, wb, used_cache).
first_get_file <- function(list, year, cache, refresh, timeout, verbose) {
  filename <- sprintf("first_%s_%d.xlsx", list, year)
  dest <- cache_path("first", year, list, "ratings", file = filename)
  if (cache && !refresh && file.exists(dest)) {
    meta <- read_sidecar(dest)
    if (!is.null(meta)) {
      if (verbose) cli::cli_alert_info("Using cached file: {dest}")
      return(list(path = dest, meta = meta, wb = read_first_workbook(dest),
                  used_cache = TRUE))
    }
  }
  if (verbose) {
    cli::cli_alert_info(
      "Downloading {first_list_label(list)} ratings for {year_label(year)}"
    )
  }
  dl <- first_download(list, year, timeout = timeout)
  meta <- c(
    list(source = "first", year = year, school_year = year_label(year),
         level = list, data_type = "ratings", dataset = NA_character_,
         file_format = "xlsx"),
    dl$meta,
    list(sha256 = sha256_file(dl$path), size_bytes = file.size(dl$path))
  )
  if (!cache) {
    return(list(path = dl$path, meta = meta, wb = dl$wb, used_cache = FALSE))
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  unlink(sidecar_path(dest))
  # Copy, not rename: tempdir() and the cache can sit on different
  # filesystems.
  if (!file.copy(dl$path, dest, overwrite = TRUE)) {
    stop("Could not write the FIRST workbook to the cache: ", dest,
         call. = FALSE)
  }
  unlink(dl$path)
  write_sidecar(dest, meta)
  list(path = dest, meta = meta, wb = dl$wb, used_cache = FALSE)
}

# Up to two attempts, each a fresh session with its own cookie jar.
# Requests inside a session are never retried on their own: the apps
# answer a stale viewstate with HTTP 500, which only a new session
# fixes. "Not published" answers are final and are not retried.
first_download <- function(list, year, timeout) {
  last <- NULL
  for (attempt in 1:2) {
    jar <- tempfile("txschools-cookies-")
    res <- tryCatch(
      first_session(list, year, timeout = timeout, cookies = jar),
      error = function(e) e
    )
    unlink(jar)
    if (!inherits(res, "error")) return(res)
    if (inherits(res, "txs_first_unavailable")) stop(res)
    last <- res
  }
  stop(conditionMessage(last), call. = FALSE)
}

first_unavailable <- function(...) {
  stop(errorCondition(paste0(...), class = "txs_first_unavailable",
                      call = NULL))
}

# One session against the School or Charter FIRST app: load the page,
# post the year change (the Download button only honors a year the
# server-side page already shows), switch to the university list if
# asked, then post the Download button. Errors name the app, list,
# and year -- never the form fields, which carry a ~35 KB viewstate.
# Returns list(path, wb, meta) for a validated workbook in tempdir().
first_session <- function(list, year, timeout, cookies) {
  url <- if (identical(list, "district")) {
    TXS_URL_SCHOOL_FIRST
  } else {
    TXS_URL_CHARTER_FIRST
  }
  app <- first_list_label(list)
  page_get <- function(u) {
    http_get(u, timeout = timeout, max_tries = 1L, cookies = cookies)
  }
  page_post <- function(u, params) {
    http_post_form(u, params, timeout = timeout, max_tries = 1L,
                   cookies = cookies)
  }

  form <- aspnet_parse_form(page_get(url))
  year_select <- aspnet_find_control(names(form$selects), "[$]ddlYear$",
                                     "year selector", app)
  value <- first_option_value(form$selects[[year_select]], year, app)
  resp <- page_post(form$action,
                    aspnet_postback_params(form, year_select, value))
  first_check_page(resp, app)
  form <- aspnet_parse_form(resp)

  if (identical(list, "university_charter")) {
    view <- aspnet_find_control(names(form$selects), "[$]ddlNonAdmin$",
                                "list selector", app)
    if (!"DistStatusUniversity" %in% form$selects[[view]]$value) {
      first_unavailable(app, " has no university-charter list for ",
                        year_label(year), ".")
    }
    params <- aspnet_postback_params(form, view, "DistStatusUniversity")
    resp <- page_post(form$action, params)
    first_check_page(resp, app)
    form <- aspnet_parse_form(resp)
  }

  button <- names(form$buttons)[form$buttons == "Download"]
  if (length(button) != 1L) {
    stop(app, " page has ", length(button), " Download buttons, not 1; ",
         "TEA's site may have changed.", call. = FALSE)
  }
  params <- aspnet_submit_params(form, button)
  resp <- page_post(form$action, params)
  body <- httr2::resp_body_raw(resp)
  if (!first_is_zip(body)) {
    stop(app, " returned a web page instead of the ", year_label(year),
         " ratings workbook.", call. = FALSE)
  }

  path <- temp_download_path("first.xlsx")
  writeBin(body, path)
  wb <- tryCatch({
    wb <- read_first_workbook(path)
    first_check_workbook(wb, list, year)
    wb
  }, error = function(e) {
    unlink(path)
    stop(e)
  })
  # Provenance keeps only the visible choices (year, list, button), not
  # ASP.NET's state fields.
  shown <- setdiff(names(params), form$hidden)
  shown <- shown[!startsWith(shown, "__")]
  list(path = path, wb = wb, meta = list(
    source_url   = url,
    method       = "post",
    params       = encode_query_params(params[shown]),
    retrieved_at = iso8601_now(),
    content_type = httr2::resp_header(resp, "Content-Type") %||% NA_character_,
    tea_title    = wb$title,
    tea_filename = first_disposition_filename(resp)
  ))
}

# A failed postback lands on the app's error page instead of an HTTP
# error.
first_check_page <- function(resp, app) {
  if (grepl("Error\\.aspx", httr2::resp_url(resp), ignore.case = TRUE)) {
    stop(app, " answered with its error page.", call. = FALSE)
  }
  invisible(resp)
}

# Year options are labeled by rating year ("2025-2026") but their values
# differ by app (School 2024 vs Charter 2025 for the same ratings), so
# match on the label.
first_option_value <- function(options, year, app) {
  opt_years <- vapply(options$label, peims_year_from_label, integer(1),
                      USE.NAMES = FALSE)
  hit <- options$value[!is.na(opt_years) & opt_years == year]
  if (!length(hit)) {
    avail <- sort(opt_years[!is.na(opt_years)])
    first_unavailable(
      app, " does not list ", year_label(year), " ratings",
      if (length(avail)) {
        sprintf(" (available: %s to %s)", year_label(min(avail)),
                year_label(max(avail)))
      },
      "."
    )
  }
  hit[[1]]
}

first_is_zip <- function(body) {
  length(body) >= 4L &&
    identical(body[1:4], as.raw(c(0x50, 0x4b, 0x03, 0x04)))
}

first_disposition_filename <- function(resp) {
  cd <- httr2::resp_header(resp, "Content-Disposition") %||% ""
  m <- regmatches(cd, regexec('filename="?([^";]+)"?', cd))[[1]]
  if (length(m) == 2L) m[2] else NA_character_
}

# --- ASP.NET WebForms ---------------------------------------------------------

# What a browser would submit from the page's (single) form: every
# hidden input, and each select's selected option (its first option when
# none is marked). Submit buttons are kept aside; a post includes at
# most the one that was "clicked". The action resolves against the
# response URL, which follows any redirect.
aspnet_parse_form <- function(resp) {
  doc <- xml2::read_html(httr2::resp_body_string(resp))
  form <- xml2::xml_find_first(doc, "//form")
  if (inherits(form, "xml_missing")) {
    stop("TEA's page has no form; the site may have changed.", call. = FALSE)
  }
  base <- httr2::resp_url(resp)
  action <- xml2::xml_attr(form, "action", default = "")
  action <- if (nzchar(action)) xml2::url_absolute(action, base) else base

  inputs <- xml2::xml_find_all(form, ".//input")
  input_type <- tolower(xml2::xml_attr(inputs, "type", default = "text"))
  input_name <- xml2::xml_attr(inputs, "name")
  input_value <- xml2::xml_attr(inputs, "value", default = "")
  is_hidden <- input_type == "hidden" & !is.na(input_name)
  is_submit <- input_type == "submit" & !is.na(input_name)
  fields <- stats::setNames(as.list(input_value[is_hidden]),
                            input_name[is_hidden])

  selects <- list()
  for (s in xml2::xml_find_all(form, ".//select")) {
    name <- xml2::xml_attr(s, "name")
    if (is.na(name)) next
    opts <- xml2::xml_find_all(s, ".//option")
    label <- trimws(xml2::xml_text(opts))
    value <- xml2::xml_attr(opts, "value")
    value[is.na(value)] <- label[is.na(value)]
    selected <- !is.na(xml2::xml_attr(opts, "selected"))
    selects[[name]] <- tibble::tibble(value = value, label = label,
                                      selected = selected)
    fields[[name]] <- if (any(selected)) {
      value[which(selected)[1]]
    } else if (length(value)) {
      value[1]
    } else {
      ""
    }
  }

  list(
    action  = action,
    fields  = fields,
    hidden  = input_name[is_hidden],
    selects = selects,
    buttons = stats::setNames(input_value[is_submit], input_name[is_submit])
  )
}

aspnet_find_control <- function(names, pattern, what, app) {
  hit <- names[grepl(pattern, names)]
  if (length(hit) != 1L) {
    stop(sprintf("%s page has %d %ss, not 1; TEA's site may have changed.",
                 app, length(hit), what), call. = FALSE)
  }
  hit
}

# A select's onchange postback. ASP.NET omits __EVENTTARGET from pages
# it serves to non-browser user agents, so it is always set here.
aspnet_postback_params <- function(form, target, value) {
  params <- form$fields
  params[[target]] <- value
  params[["__EVENTTARGET"]] <- target
  params[["__EVENTARGUMENT"]] <- ""
  params
}

# A submit-button click: the form's fields plus that one button.
aspnet_submit_params <- function(form, button) {
  params <- form$fields
  params[["__EVENTTARGET"]] <- ""
  params[["__EVENTARGUMENT"]] <- ""
  params[[button]] <- form$buttons[[button]]
  params
}

# --- Parsing ------------------------------------------------------------------

# Normalized header of every FIRST workbook (all years, all lists).
first_headers <- c("district#", "district_name", "status", "rating", "score",
                   "last updated date", "region")

# Title row(s) above the header, then one row per district or charter.
# Columns are read as text; District# (numeric in the file) keeps only
# rows that hold a number, which drops blank and footer rows. Returns
# list(title, data) with TEA's column names.
read_first_workbook <- function(path) {
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE,
                            col_types = "text", .name_repair = "minimal")
  hdr <- find_header_row(raw, must = c("district#", "rating"))
  header <- as.character(unlist(raw[hdr, ], use.names = FALSE))
  cols <- match(first_headers, norm_header(header))
  if (anyNA(cols)) {
    stop("TEA's FIRST workbook layout changed; missing column(s): ",
         paste(first_headers[is.na(cols)], collapse = ", "), ".",
         call. = FALSE)
  }
  above <- unlist(raw[seq_len(hdr - 1L), ], use.names = FALSE)
  title <- peims_clean_text(paste(above[!is.na(above)], collapse = " "))
  data <- raw[-seq_len(hdr), cols, drop = FALSE]
  names(data) <- trimws(header[cols])
  keep <- grepl("^\\s*[0-9]+(\\.0+)?\\s*$", data[[1]])
  list(title = if (nzchar(title)) title else NA_character_,
       data = tibble::as_tibble(data[keep, , drop = FALSE]))
}

# A silently failed postback would hand back the default year or list;
# check the workbook is the one asked for before it is cached.
first_check_workbook <- function(wb, list, year) {
  title <- wb$title
  got <- if (is.na(title)) NA_integer_ else peims_year_from_label(title)
  if (is.na(got) || got != year) {
    stop(sprintf(
      "TEA returned a workbook for %s, not %s.",
      if (is.na(got)) "an unlabeled year" else year_label(got),
      year_label(year)
    ), call. = FALSE)
  }
  charter <- grepl("CharterFIRST", title, ignore.case = TRUE)
  university <- grepl("University", title, ignore.case = TRUE)
  if (charter != (list != "district") ||
      university != (list == "university_charter")) {
    stop("TEA returned a different FIRST list (", title, ") than ",
         first_list_label(list), ".", call. = FALSE)
  }
  invisible(wb)
}

first_tidy <- function(data, list, year, meta) {
  # Scalars first: inside tibble(), `year` would mean the new column.
  n <- nrow(data)
  yr <- as.integer(year)
  release <- first_release(list, meta$tea_title, meta$retrieved_at, yr)
  id <- suppressWarnings(as.integer(as.numeric(data[[1]])))
  region <- suppressWarnings(as.integer(as.numeric(data[[7]])))
  rating <- first_text(data[[4]])
  tibble::tibble(
    year               = rep(yr, n),
    school_year        = rep(year_label(yr), n),
    fiscal_year        = rep(yr - 1L, n),
    type               = rep(if (identical(list, "district")) "district"
                             else "charter", n),
    university_charter = rep(identical(list, "university_charter"), n),
    district           = first_pad(id, "%06d"),
    district_name      = first_text(data[[2]]),
    region             = first_pad(region, "%02d"),
    status             = first_text(data[[3]]),
    rating             = rating,
    grade              = first_grade(rating),
    score              = suppressWarnings(as.numeric(data[[5]])),
    release            = rep(release, n),
    last_updated       = first_excel_date(data[[6]])
  )
}

# Zero-padded IDs; NA stays NA (sprintf("%06d", NA) is "0000NA").
first_pad <- function(x, fmt) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  out[ok] <- sprintf(fmt, x[ok])
  out
}

first_text <- function(x) {
  x <- peims_clean_text(x)
  x[!is.na(x) & !nzchar(x)] <- NA_character_
  x
}

# Letter grades exist from 2015-16 on: "A = Superior Achievement"
# (School FIRST) or "A - Superior Achievement" (Charter FIRST).
first_grade <- function(rating) {
  m <- regmatches(rating, regexec("^\\s*([ABCF])\\s*[=-]", rating))
  vapply(m, function(z) if (length(z) == 2L) z[2] else NA_character_,
         character(1))
}

# "preliminary" when TEA's title says so (Charter FIRST labels
# correctly) or, for School FIRST -- which titles every workbook
# "Final" -- when the copy was downloaded before TEA's usual final
# release for that rating year.
first_release <- function(list, title, retrieved_at, year) {
  if (isTRUE(grepl("preliminary", title, ignore.case = TRUE))) {
    return("preliminary")
  }
  if (identical(list, "district")) {
    got <- as.Date(substr(retrieved_at %||% NA_character_, 1, 10))
    if (is.na(got)) got <- Sys.Date()
    if (got < first_final_cutoff(year)) return("preliminary")
  }
  "final"
}

first_final_cutoff <- function(year) {
  as.Date(paste0(year, "-", TXS_FIRST_FINAL_CUTOFF))
}

# Excel serial day numbers (the fraction is the time of day).
first_excel_date <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  as.Date(floor(x), origin = "1899-12-30")
}

# One line about preliminary ratings: a reminder to refresh cached
# copies that predate TEA's final release, or a heads-up that freshly
# downloaded ratings are still preliminary.
first_note_release <- function(parts) {
  prelim <- Filter(function(p) {
    identical(first_release(p$list, p$meta$tea_title, p$meta$retrieved_at,
                            p$year), "preliminary")
  }, parts)
  if (!length(prelim)) return(invisible())
  stale <- vapply(prelim, function(p) {
    isTRUE(p$used_cache) && Sys.Date() >= first_final_cutoff(p$year)
  }, logical(1))
  if (any(stale)) {
    sy <- unique(vapply(prelim[stale], function(p) year_label(p$year),
                        character(1)))
    cli::cli_alert_info(paste0(
      "Cached {sy} FIRST ratings were downloaded before TEA's final ",
      "release; re-run with {.code refresh = TRUE} to update them."
    ))
  } else {
    sy <- unique(vapply(prelim, function(p) year_label(p$year), character(1)))
    cli::cli_alert_info(paste0(
      "{sy} FIRST ratings are preliminary until TEA posts final ratings ",
      "(by mid-November); see the {.field release} column."
    ))
  }
  invisible()
}
