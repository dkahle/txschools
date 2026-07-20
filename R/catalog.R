# Static, hand-authored URL catalog. Bundled with the package as
# inst/extdata/source_catalog.yml; never contains TEA data, only URL
# templates and labels.

catalog_path <- function() {
  system.file("extdata", "source_catalog.yml", package = "txschools")
}

#' Read the bundled URL/source catalog
#'
#' Returns the parsed catalog as a list. The catalog is a hand-authored
#' YAML file (`inst/extdata/source_catalog.yml`) that documents the
#' TAPR/SRC/AEIS/PEIMS base URLs, known years, and filename patterns. It is
#' the fallback that `discover_*` functions consult when live HTML
#' parsing fails or `refresh = FALSE`.
#'
#' @keywords internal
#' @export
txs_catalog <- function() {
  p <- catalog_path()
  if (!nzchar(p) || !file.exists(p)) {
    # During devtools::load_all() the file is at inst/extdata/.
    here <- file.path("inst", "extdata", "source_catalog.yml")
    if (file.exists(here)) p <- here else return(list())
  }
  yaml::read_yaml(p)
}

catalog_source <- function(source = c("tapr", "src", "aeis", "peims",
                                      "taxrates")) {
  source <- match.arg(source)
  cat <- txs_catalog()
  cat[[source]] %||% list()
}

catalog_years <- function(source) {
  cat <- catalog_source(source)
  yrs <- c(cat$years, cat$years_html, cat$years_pdf)
  if (is.null(yrs)) integer(0) else sort(unique(as.integer(unlist(yrs))))
}

catalog_broker_url <- function() {
  txs_catalog()$broker %||% TXS_BROKER_URL
}

# Expand a URL template. Spaces are percent-encoded (TEA's "Basic
# Download" paths contain literal spaces).
catalog_url <- function(template, base, year) {
  url <- template
  url <- gsub("\\{base\\}", base, url, fixed = FALSE)
  url <- gsub("\\{year_label\\}", year_label(year), url, fixed = FALSE)
  url <- gsub("\\{end_year\\}", sprintf("%d", as.integer(year)), url, fixed = FALSE)
  url <- gsub("\\{year\\}", sprintf("%d", as.integer(year)), url, fixed = FALSE)
  url <- gsub("\\{yy\\}", sprintf("%02d", as.integer(year) %% 100L), url, fixed = FALSE)
  gsub(" ", "%20", url, fixed = TRUE)
}
