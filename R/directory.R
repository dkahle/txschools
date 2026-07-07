#' Texas school and district directory
#'
#' Builds a searchable directory of Texas campuses or districts --
#' names, TEA identifiers, districts, counties, regions, and grade
#' spans -- from the statewide TAPR reference dataset (`REF`), the same
#' public file TEA serves through its Advanced Download interface. Use
#' it to look up the nine-digit campus (or six-digit district) numbers
#' that [txs_get_tapr()] and friends require.
#'
#' @param year Integer ending year of the TAPR reference file to use.
#'   `NULL` (default) uses the most recent year that resolves.
#' @param level `"campus"` or `"district"`.
#' @param cache,refresh,timeout,verbose Passed to the underlying
#'   download; see [txs_get_tapr_file()].
#' @return A tibble with columns `year`, `level`, `id`, `name`,
#'   `district`, `district_name`, `county_name`, `region`, and
#'   `grade_span` (columns not published for a level are `NA`).
#'   Identifiers are character vectors to preserve leading zeros.
#' @examples
#' \dontrun{
#' txs_directory(2024, "campus")
#' }
#' @seealso [txs_find_campus()], [txs_find_district()]
#' @export
txs_directory <- function(year = NULL,
                          level = c("campus", "district"),
                          cache = TRUE,
                          refresh = FALSE,
                          timeout = 60,
                          verbose = TRUE) {
  level <- match.arg(level)

  years <- if (is.null(year)) {
    sort(catalog_years("tapr"), decreasing = TRUE)[1:3]
  } else {
    normalize_year(year, source = "tapr")
  }

  last_error <- NULL
  for (yr in years) {
    out <- tryCatch(
      directory_from_ref(yr, level, cache = cache, refresh = refresh,
                         timeout = timeout, verbose = verbose),
      error = function(e) { last_error <<- e; NULL }
    )
    if (!is.null(out)) return(out)
    if (verbose && is.null(year)) {
      cli::cli_alert_info(
        "TAPR reference data for {yr} not available; trying an earlier year."
      )
    }
  }
  stop(
    "Could not build the ", level, " directory",
    if (!is.null(year)) sprintf(" for %d", years[1]),
    ": ", conditionMessage(last_error),
    call. = FALSE
  )
}

directory_from_ref <- function(year, level, cache, refresh, timeout, verbose) {
  ref <- txs_get_tapr_file(
    year = year, level = level, dataset = "REF",
    data_type = "advanced", file_format = "csv",
    cache = cache, refresh = refresh, output = "raw",
    timeout = timeout, verbose = verbose
  )
  nms <- toupper(names(ref))
  pick <- function(candidates) {
    hit <- which(nms %in% candidates)
    if (length(hit)) as.character(ref[[hit[1]]]) else rep(NA_character_, nrow(ref))
  }
  id <- if (identical(level, "campus")) {
    pick(c("CAMPUS", "CAMPUS_NUMBER"))
  } else {
    pick(c("DISTRICT", "DISTRICT_NUMBER"))
  }
  name <- if (identical(level, "campus")) {
    pick(c("CAMPNAME", "CAMPUS_NAME"))
  } else {
    pick(c("DISTNAME", "DISTRICT_NAME"))
  }
  if (all(is.na(id)) || all(is.na(name))) {
    stop("TAPR reference file did not contain the expected identifier columns.",
         call. = FALSE)
  }
  # TEA prefixes identifiers with an apostrophe so spreadsheets keep
  # leading zeros ("'161920102"); strip it, we return plain strings.
  clean_id <- function(x) trimws(sub("^'", "", x))

  district <- if (identical(level, "campus")) {
    clean_id(pick(c("DISTRICT", "DISTRICT_NUMBER")))
  } else {
    clean_id(id)
  }
  district_name <- if (identical(level, "campus")) {
    trimws(pick(c("DISTNAME", "DISTRICT_NAME")))
  } else {
    trimws(name)
  }

  out <- tibble::tibble(
    year          = as.integer(year),
    level         = level,
    id            = clean_id(id),
    name          = trimws(name),
    district      = district,
    district_name = district_name,
    county_name   = trimws(pick(c("CNTYNAME", "COUNTY_NAME"))),
    region        = clean_id(pick(c("REGION", "ESC_REGION"))),
    grade_span    = clean_id(pick(c("GRDSPAN", "GRADE_SPAN")))
  )
  out[!is.na(out$id) & nzchar(out$id), , drop = FALSE]
}

#' Find a campus or district by name
#'
#' Case-insensitive pattern search over the TEA directory built by
#' [txs_directory()]. Returns matching rows with the quoted identifiers
#' expected by [txs_get_tapr()], [txs_get_src()], and [txs_get_aeis()].
#'
#' @param pattern A regular expression (case-insensitive) matched
#'   against campus/district names. For campuses, the district name is
#'   searched too, so `txs_find_campus("china spring")` returns every
#'   campus in China Spring ISD.
#' @param year Integer ending year of the TAPR reference file to use.
#'   `NULL` (default) uses the most recent year that resolves.
#' @param cache,refresh,verbose Passed to the underlying download; see
#'   [txs_get_tapr_file()].
#' @return A tibble; see [txs_directory()].
#' @examples
#' \dontrun{
#' txs_find_campus("china spring")
#' txs_find_district("waco")
#' }
#' @export
txs_find_campus <- function(pattern,
                            year = NULL,
                            cache = TRUE,
                            refresh = FALSE,
                            verbose = FALSE) {
  dir <- txs_directory(year = year, level = "campus", cache = cache,
                       refresh = refresh, verbose = verbose)
  keep <- grepl(pattern, dir$name, ignore.case = TRUE) |
    grepl(pattern, dir$district_name, ignore.case = TRUE)
  dir[keep, , drop = FALSE]
}

#' @rdname txs_find_campus
#' @export
txs_find_district <- function(pattern,
                              year = NULL,
                              cache = TRUE,
                              refresh = FALSE,
                              verbose = FALSE) {
  dir <- txs_directory(year = year, level = "district", cache = cache,
                       refresh = refresh, verbose = verbose)
  dir[grepl(pattern, dir$name, ignore.case = TRUE), , drop = FALSE]
}
