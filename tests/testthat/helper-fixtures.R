# Resolve the path to a fixture, whether tests run from the package
# root (devtools::test()) or from tests/testthat/ (R CMD check).
fixture_path <- function(name) {
  candidates <- c(
    testthat::test_path("fixtures", name),
    file.path("tests", "testthat", "fixtures", name),
    file.path("fixtures", name)
  )
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) stop("Fixture not found: ", name)
  hit[1]
}

# Read a fixture HTML file as a string (for stubbing http responses).
fixture_html <- function(name) {
  readChar(fixture_path(name), file.info(fixture_path(name))$size,
           useBytes = TRUE)
}

# Use a temp dir as the txschools cache for the duration of a test.
local_cache <- function(.local_envir = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = .local_envir)
  withr::local_options(
    txschools.cache_dir = dir,
    .local_envir = .local_envir
  )
  dir
}
