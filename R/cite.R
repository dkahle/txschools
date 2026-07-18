#' Build a citation
#'
#' Produces a [utils::bibentry()] suitable for printing or passing to
#' `format()`. If `x` is a tibble returned by [txs_get_tapr_file()] (or
#' its sibling functions), the citation references that specific file by
#' source URL, retrieval timestamp, and short SHA-256 prefix. If `x` is a
#' semantic TAPR object from [txs_get_tapr()], the citation references the
#' semantic pull and its source pages.
#'
#' @param x Optional. A tibble returned by `txs_get_*()`. If `NULL`,
#'   returns a generic citation for the named `source`.
#' @param source `"tapr"`, `"src"`, `"aeis"`, or `"peims"`.
#' @return A `bibentry`.
#' @examples
#' txs_cite(source = "tapr")
#' @export
txs_cite <- function(x = NULL, source = "tapr") {
  if (!is.null(x) && inherits(x, "tapr")) {
    meta <- attr(x, "txschools")
    pages <- meta$pages
    url <- if (!is.null(pages) && nrow(pages)) {
      pages$source_url[[1]]
    } else {
      TXS_LANDING_TAPR
    }
    retrieved <- if (!is.null(pages) && nrow(pages)) {
      pages$retrieved_at[[1]]
    } else {
      NA_character_
    }
    return(utils::bibentry(
      bibtype = "Misc",
      title = sprintf(
        "TAPR semantic datasets for %s",
        paste(meta$school_years, collapse = ", ")
      ),
      author = utils::person(family = "Texas Education Agency"),
      year = substr(retrieved %||% as.character(Sys.Date()), 1, 4),
      url = url,
      note = sprintf(
        "Retrieved via the txschools R package for geography %s.",
        paste(meta$geography, collapse = ", ")
      ),
      publisher = "Texas Education Agency"
    ))
  }
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
  source <- match.arg(source, c("tapr", "src", "aeis", "peims"))
  prog <- switch(
    source,
    tapr = list(name = "Texas Academic Performance Reports",
                url  = TXS_LANDING_TAPR),
    aeis = list(name = "Academic Excellence Indicator System",
                url  = "https://rptsvr1.tea.texas.gov/perfreport/aeis/"),
    src  = list(name = "School Report Card",
                url  = "https://rptsvr1.tea.texas.gov/perfreport/src/"),
    peims = list(name = "PEIMS Financial Data (single file)",
                 url  = TXS_INDEX_PEIMS)
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
