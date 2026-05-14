#' Internal HTTP helpers
#'
#' Thin wrappers around `httr2` that enforce:
#' - a clear, package-identifying User-Agent,
#' - per-host throttling (configurable via `options("txschools.rate_per_sec")`),
#' - retries with exponential back-off on transient errors,
#' - configurable timeout (`options("txschools.timeout")`),
#' - a `robots.txt` check before each request.
#'
#' @keywords internal
#' @name txs-http
NULL

#' @rdname txs-http
http_request <- function(url, timeout = NULL, max_tries = NULL) {
  if (!check_robots(url)) {
    stop(
      sprintf(
        "txschools: robots.txt for %s disallows this path. ",
        httr2::url_parse(url)$hostname
      ),
      "Set options(txschools.respect_robots = FALSE) only if you have ",
      "explicit permission from the site owner.",
      call. = FALSE
    )
  }
  rate    <- getOption("txschools.rate_per_sec", TXS_RATE_DEFAULT)
  timeout <- timeout %||% getOption("txschools.timeout", TXS_TIMEOUT_DEFAULT)
  max_tries <- max_tries %||% TXS_MAX_TRIES
  ua <- getOption("txschools.user_agent", TXS_USER_AGENT_BASE)
  host <- httr2::url_parse(url)$hostname

  httr2::request(url) |>
    httr2::req_user_agent(ua) |>
    httr2::req_timeout(timeout) |>
    httr2::req_throttle(rate = rate, realm = host) |>
    httr2::req_retry(
      max_tries    = max_tries,
      backoff      = function(i) min(2 ^ i, 30),
      is_transient = function(resp) httr2::resp_status(resp) %in% c(408, 425, 429, 500, 502, 503, 504)
    )
}

#' @rdname txs-http
http_get <- function(url, timeout = NULL, max_tries = NULL) {
  req <- http_request(url, timeout = timeout, max_tries = max_tries)
  httr2::req_perform(req)
}

#' Download a URL to a file, returning metadata.
#'
#' @rdname txs-http
http_download <- function(url, dest, timeout = NULL, max_tries = NULL) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  req <- http_request(url, timeout = timeout, max_tries = max_tries)
  resp <- httr2::req_perform(req, path = dest)
  list(
    path         = dest,
    sha256       = sha256_file(dest),
    size_bytes   = file.size(dest),
    content_type = httr2::resp_header(resp, "Content-Type") %||% NA_character_,
    retrieved_at = iso8601_now(),
    source_url   = url
  )
}
