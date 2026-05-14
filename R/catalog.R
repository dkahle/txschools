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
#' TAPR/SRC/AEIS base URLs, known years, and filename patterns. It is
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

catalog_source <- function(source = c("tapr", "src", "aeis")) {
  source <- match.arg(source)
  cat <- txs_catalog()
  cat[[source]] %||% list()
}

catalog_years <- function(source) {
  yrs <- catalog_source(source)$years
  if (is.null(yrs)) integer(0) else as.integer(yrs)
}

# Expand a "{base}/{year_label}/..." template.
catalog_url <- function(template, base, year) {
  url <- template
  url <- gsub("\\{base\\}", base, url, fixed = FALSE)
  url <- gsub("\\{year_label\\}", year_label(year), url, fixed = FALSE)
  url <- gsub("\\{end_year\\}", sprintf("%d", as.integer(year) + 1L), url, fixed = FALSE)
  url <- gsub("\\{year\\}", sprintf("%d", as.integer(year)), url, fixed = FALSE)
  url
}
