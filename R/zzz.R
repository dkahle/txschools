.onLoad <- function(libname, pkgname) {
  defaults <- list(
    txschools.rate_per_sec  = TXS_RATE_DEFAULT,
    txschools.timeout       = TXS_TIMEOUT_DEFAULT,
    txschools.respect_robots = TRUE,
    txschools.user_agent    = paste0(
      sub(" R package", sprintf("/%s R package", as.character(utils::packageVersion(pkgname))),
          TXS_USER_AGENT_BASE)
    ),
    txschools.cache_dir     = NULL,  # NULL means tools::R_user_dir()
    txschools.bulk_delay    = 5
  )
  unset <- setdiff(names(defaults), names(options()))
  if (length(unset)) options(defaults[unset])

  # Session-local robots.txt cache.
  assign(".txs_robots_cache", new.env(parent = emptyenv()), envir = topenv())
  invisible()
}
