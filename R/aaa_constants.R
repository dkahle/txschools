#' Package-level constants
#'
#' Internal constants used to identify TEA endpoints, build the HTTP
#' user-agent string, and enumerate the set of masking codes that
#' `txschools` preserves verbatim.
#'
#' @keywords internal
#' @name txs-constants
NULL

#' @rdname txs-constants
TXS_BASE_TAPR <- "https://rptsvr1.tea.texas.gov/perfreport/tapr"

#' @rdname txs-constants
TXS_BASE_AEIS <- "https://rptsvr1.tea.texas.gov/perfreport/aeis"

#' @rdname txs-constants
TXS_BASE_SRC  <- "https://rptsvr1.tea.texas.gov/perfreport/src"

#' @rdname txs-constants
TXS_LANDING_TAPR <- paste0(
  "https://tea.texas.gov/texas-schools/accountability/",
  "academic-accountability/performance-reporting/",
  "texas-academic-performance-reports"
)

# Codes TEA uses to mask or suppress cell values. These are preserved as
# strings; the package will never coerce them to NA without an explicit
# `masked` flag traveling alongside.
TXS_MASK_VALUES <- c(".", "*", "-1", "-2", "-3", "-4", "-99", "n/a", "N/A")

TXS_RATE_DEFAULT     <- 1     # request per second
TXS_TIMEOUT_DEFAULT  <- 60    # seconds
TXS_MAX_TRIES        <- 3
TXS_FIRST_TAPR_YEAR  <- 2013
TXS_FIRST_AEIS_YEAR  <- 2004
TXS_LAST_AEIS_YEAR   <- 2012

# Static UA string. We append the installed package version at runtime in
# zzz.R rather than calling utils::packageVersion() at parse time (which
# would resolve to NA during R CMD check installs).
TXS_USER_AGENT_BASE <- "txschools R package (+https://github.com/dkahle/txschools)"
