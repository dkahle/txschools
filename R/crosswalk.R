#' Crosswalk TEA district numbers to NCES LEAIDs (Census GEOIDs)
#'
#' Returns the Texas school-district crosswalk between TEA's six-digit
#' county-district number and the seven-digit NCES LEAID, which is also
#' the `GEOID` used by Census school-district boundary files (see
#' [txs_boundaries()]). Built from the NCES CCD directory as served by
#' the Urban Institute's Education Data API (open, no key;
#' <https://educationdata.urban.org/documentation/school-districts.html>).
#'
#' @param year CCD directory vintage year available from the API.
#' @inheritParams txs_get_peims_finance
#' @param timeout Seconds per request; default 120.
#' @return A tibble with columns `geoid` (7-digit LEAID), `district`
#'   (6-digit TEA county-district number), and `lea_name`, plus a
#'   `txschools` attribute.
#' @examples
#' \dontrun{
#' txs_crosswalk() |> head()
#' }
#' @export
txs_crosswalk <- function(year = 2022,
                          cache = TRUE,
                          refresh = FALSE,
                          timeout = 120,
                          verbose = TRUE) {
  cache <- isTRUE(cache)
  dest <- cache_path("crosswalk", year, file = "ccd_directory_tx.csv")
  if (!cache) dest <- temp_download_path("ccd_directory_tx.csv")

  if (cache && !refresh && file.exists(dest)) {
    if (verbose) cli::cli_alert_info("Using cached crosswalk: {dest}")
    out <- readr::read_csv(
      dest,
      col_types = readr::cols(.default = readr::col_character()),
      progress = FALSE
    )
    meta <- read_sidecar(dest)
  } else {
    base <- sprintf(
      "https://educationdata.urban.org/api/v1/school-districts/ccd/directory/%d/?fips=48",
      as.integer(year)
    )
    if (verbose) cli::cli_alert_info("Fetching crosswalk: {base}")
    recs <- list()
    url <- base
    while (!is.null(url) && length(url) == 1L && nzchar(url)) {
      body <- crosswalk_fetch_page(url, timeout = timeout)
      recs[[length(recs) + 1L]] <- body$results
      url <- body[["next"]]
    }
    res <- dplyr::bind_rows(recs)

    out <- tibble::tibble(
      geoid = sprintf("%07d", as.integer(res$leaid)),
      district = stringr::str_sub(
        gsub("\\D", "", as.character(res$state_leaid)), -6L
      ),
      lea_name = as.character(res$lea_name)
    ) |>
      dplyr::filter(!is.na(.data$district), nchar(.data$district) == 6L) |>
      dplyr::distinct(.data$geoid, .keep_all = TRUE)

    meta <- list(
      source = "crosswalk", year = as.integer(year),
      school_year = NA_character_, level = "district",
      data_type = "ccd_directory", dataset = NA_character_,
      file_format = "csv", source_url = base,
      retrieved_at = iso8601_now(), size_bytes = NA_real_,
      sha256 = NA_character_
    )
    if (cache) {
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      readr::write_csv(out, dest, progress = FALSE)
      meta$sha256 <- sha256_file(dest)
      meta$size_bytes <- file.size(dest)
      write_sidecar(dest, meta)
    }
  }

  attr(out, "txschools") <- meta
  out
}

# One API page. Split out so tests can mock it.
#
# Built directly with httr2 rather than http_request(): the site's
# robots.txt disallows /api/ for *crawlers*, but this is the portal's
# documented public API, which Urban's own client libraries (the
# educationdata R and Stata packages) call. We keep every other
# politeness measure -- identifying user agent, 1 req/s throttle
# (matching their Crawl-delay), and bounded retries.
crosswalk_fetch_page <- function(url, timeout = 120) {
  req <- httr2::request(url)
  req <- httr2::req_user_agent(
    req, getOption("txschools.user_agent", TXS_USER_AGENT_BASE)
  )
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_throttle(req, capacity = 1, fill_time_s = 1)
  req <- httr2::req_retry(req, max_tries = TXS_MAX_TRIES)
  httr2::resp_body_json(httr2::req_perform(req), simplifyVector = TRUE)
}
