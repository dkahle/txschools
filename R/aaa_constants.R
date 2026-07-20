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
TXS_BROKER_URL <- "https://rptsvr1.tea.texas.gov/cgi/sas/broker"

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

#' @rdname txs-constants
TXS_INDEX_PEIMS <- paste0(
  "https://tea.texas.gov/about-tea/state-funding/",
  "state-funding-reports-and-data/",
  "peims-single-file-financial-data-downloads"
)

#' @rdname txs-constants
TXS_INDEX_PEIMS_CODES <- paste0(
  "https://tea.texas.gov/about-tea/state-funding/",
  "state-funding-reports-and-data/",
  "peims-multiple-file-financial-data-downloads"
)

# Codes TEA uses to mask or suppress cell values. These are preserved as
# strings; the package will never coerce them to NA without an explicit
# `masked` flag traveling alongside.
TXS_MASK_VALUES <- c(
  ".", "*", "-", "---", "-1", "-2", "-3", "-4", "-99", "n/a", "N/A"
)

TXS_RATE_DEFAULT     <- 1     # request per second
TXS_TIMEOUT_DEFAULT  <- 60    # seconds
TXS_MAX_TRIES        <- 3
TXS_FIRST_TAPR_YEAR  <- 2013
TXS_FIRST_AEIS_YEAR  <- 2004
TXS_LAST_AEIS_YEAR   <- 2012
TXS_FIRST_SRC_YEAR   <- 2004
TXS_LAST_SRC_HTML_YEAR <- 2012
TXS_LAST_SRC_YEAR    <- 2019
TXS_FIRST_PEIMS_YEAR <- 2000
TXS_FIRST_TAXRATES_YEAR <- 2006
TXS_FIRST_COMPTROLLER_TAXYEAR <- 2019

#' @rdname txs-constants
TXS_INDEX_COMPTROLLER_RATES <-
  "https://comptroller.texas.gov/taxes/property-tax/rates/"

#' @rdname txs-constants
TXS_URL_TEA_ADOPTED_RATES <- paste0(
  "https://tea.texas.gov/about-tea/state-funding/",
  "additional-finance-resources/school-district-adopted-tax-rates-1.xlsx"
)

# Static UA string. We append the installed package version at runtime in
# zzz.R rather than calling utils::packageVersion() at parse time (which
# would resolve to NA during R CMD check installs).
TXS_USER_AGENT_BASE <- "txschools R package (+https://github.com/dkahle/txschools)"
