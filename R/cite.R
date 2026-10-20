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
#' @param source One of `"tapr"`, `"src"`, `"aeis"`, `"peims"`,
#'   `"taxrates"`, `"first"`, `"crosswalk"`, `"boundaries"`.
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
  if (!is.null(x) && !is.null(attr(x, "txschools")) &&
      isTRUE(attr(x, "txschools")$source %in%
               c("taxrates", "first", "crosswalk", "boundaries"))) {
    # Non-TEA, multi-publisher, or multi-file sources: cite the
    # program, noting the retrieval time recorded on the object.
    meta <- attr(x, "txschools")
    bib <- txs_cite(source = meta$source)
    retrieved <- meta$retrieved_at %||% NA_character_
    if (!is.na(retrieved)) {
      bib$note <- paste0(bib$note, " Retrieved ", retrieved, ".")
    }
    return(bib)
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
  source <- match.arg(source, c("tapr", "src", "aeis", "peims", "taxrates",
                                "first", "crosswalk", "boundaries"))
  prog <- switch(
    source,
    tapr = list(name = "Texas Academic Performance Reports",
                url  = TXS_LANDING_TAPR,
                publisher = "Texas Education Agency"),
    aeis = list(name = "Academic Excellence Indicator System",
                url  = "https://rptsvr1.tea.texas.gov/perfreport/aeis/",
                publisher = "Texas Education Agency"),
    src  = list(name = "School Report Card",
                url  = "https://rptsvr1.tea.texas.gov/perfreport/src/",
                publisher = "Texas Education Agency"),
    peims = list(name = "PEIMS Financial Data (single file)",
                 url  = TXS_INDEX_PEIMS,
                 publisher = "Texas Education Agency"),
    taxrates = list(
      name = "School District Property Tax Rates and Levies",
      url  = TXS_INDEX_COMPTROLLER_RATES,
      publisher = "Texas Comptroller of Public Accounts",
      note = paste(
        "Public data; accessed via the txschools R package.",
        "School years before 2019-20 (and gaps) derive from the Texas",
        "Education Agency adopted-tax-rates workbook:",
        TXS_URL_TEA_ADOPTED_RATES
      )
    ),
    first = list(
      name = paste(
        "Financial Integrity Rating System of Texas (FIRST) ratings:",
        "School FIRST and Charter FIRST"
      ),
      url  = TXS_LANDING_FIRST,
      publisher = "Texas Education Agency"
    ),
    crosswalk = list(
      name = "Education Data Portal: CCD school district directory",
      url  = "https://educationdata.urban.org/",
      publisher = "Urban Institute"
    ),
    boundaries = list(
      name = "Cartographic Boundary Files: Unified School Districts",
      url  = "https://www.census.gov/geographies/mapping-files.html",
      publisher = "U.S. Census Bureau"
    )
  )
  utils::bibentry(
    bibtype = "Misc",
    title   = prog$name,
    author  = utils::person(family = prog$publisher),
    year    = format(Sys.Date(), "%Y"),
    url     = prog$url,
    publisher = prog$publisher,
    note    = prog$note %||%
      "Public data; accessed via the txschools R package."
  )
}
