#' Check robots.txt for a URL
#'
#' Caches the result per host for the current R session in
#' `.txs_robots_cache` (created in `.onLoad`).
#'
#' @param url Target URL.
#' @return `TRUE` if the path is permitted (or robots.txt is missing),
#'   `FALSE` otherwise. If
#'   `options("txschools.respect_robots")` is `TRUE` and the path is
#'   disallowed, the caller is expected to refuse the request.
#' @keywords internal
check_robots <- function(url) {
  if (!isTRUE(getOption("txschools.respect_robots", TRUE))) return(TRUE)

  cache <- get0(".txs_robots_cache", envir = topenv(), inherits = FALSE)
  if (is.null(cache)) {
    cache <- new.env(parent = emptyenv())
    assign(".txs_robots_cache", cache, envir = topenv())
  }
  parsed <- httr2::url_parse(url)
  host <- parsed$hostname
  key  <- paste(host, parsed$path %||% "/", sep = "|")
  if (!is.null(cache[[key]])) return(cache[[key]])

  ua <- getOption("txschools.user_agent", TXS_USER_AGENT_BASE)
  allowed <- tryCatch(
    robotstxt::paths_allowed(paths = url, bot = ua),
    error = function(e) {
      # If robots.txt itself fails to load (e.g. 404 on rptsvr1),
      # default to "allowed" but throttle aggressively.
      TRUE
    }
  )
  ok <- isTRUE(allowed) || (is.logical(allowed) && length(allowed) && all(allowed, na.rm = TRUE))
  cache[[key]] <- ok
  ok
}

`%||%` <- function(a, b) if (is.null(a)) b else a
