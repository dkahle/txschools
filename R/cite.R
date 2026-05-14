#' Build a citation
#'
#' Produces a [utils::bibentry()] suitable for printing or passing to
#' `format()`. If `x` is a tibble returned by [txs_get_tapr()] (or its
#' sibling functions), the citation references that specific file by
#' source URL, retrieval timestamp, and short SHA-256 prefix.
#'
#' @param x Optional. A tibble returned by `txs_get_*()`. If `NULL`,
#'   returns a generic citation for the named `source`.
#' @param source `"tapr"`, `"src"`, or `"aeis"`.
#' @return A `bibentry`.
#' @examples
#' txs_cite(source = "tapr")
#' @export
txs_cite <- function(x = NULL, source = c("tapr", "src", "aeis")) {
  if (!is.null(x) && !is.null(attr(x, "txschools"))) {
    meta <- attr(x, "txschools")
    return(utils::bibentry(
      bibtype = "Misc",
      title   = sprintf(
        "%s %s, %s-level (%s, %s)",
        toupper(meta$source),
        meta$school_year,
        meta$level,
        meta$data_type,
        meta$file_format
      ),
      author = utils::person(family = "Texas Education Agency"),
      year   = substr(meta$retrieved_at, 1, 4),
      url    = meta$source_url,
      note   = sprintf(
        "Retrieved %s via the txschools R package; SHA-256 %s.",
        meta$retrieved_at,
        substr(meta$sha256, 1, 12)
      ),
      publisher = "Texas Education Agency"
    ))
  }
  source <- match.arg(source)
  prog <- switch(
    source,
    tapr = list(name = "Texas Academic Performance Reports",
                url  = TXS_LANDING_TAPR),
    aeis = list(name = "Academic Excellence Indicator System",
                url  = "https://rptsvr1.tea.texas.gov/perfreport/aeis/"),
    src  = list(name = "School Report Card",
                url  = "https://rptsvr1.tea.texas.gov/perfreport/src/")
  )
  utils::bibentry(
    bibtype = "Misc",
    title   = prog$name,
    author  = utils::person(family = "Texas Education Agency"),
    year    = format(Sys.Date(), "%Y"),
    url     = prog$url,
    publisher = "Texas Education Agency",
    note    = "Public data; accessed via the txschools R package."
  )
}
