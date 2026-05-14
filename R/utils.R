#' Normalize a TEA "school year" argument
#'
#' The package uses the *ending* calendar year to identify a TEA
#' school year, matching TEA report URLs and `ccyy` parameters. For
#' example, `2025` means the 2024-25 school year. This helper
#' validates the input and returns an integer.
#'
#' @param year Integer scalar; the ending calendar year.
#' @return Integer scalar.
#' @keywords internal
normalize_year <- function(year) {
  if (length(year) != 1L) {
    stop("`year` must be a single value.", call. = FALSE)
  }
  if (is.character(year)) {
    stop(
      "`year` must be an integer like 2024, not a string. ",
      "Use 2024 to mean the 2023-24 school year.",
      call. = FALSE
    )
  }
  y <- suppressWarnings(as.integer(year))
  if (is.na(y)) stop("`year` could not be coerced to integer.", call. = FALSE)
  current <- as.integer(format(Sys.Date(), "%Y"))
  if (y < TXS_FIRST_AEIS_YEAR || y > current) {
    stop(
      sprintf(
        "`year` = %d is out of range (%d..%d).",
        y, TXS_FIRST_AEIS_YEAR, current
      ),
      call. = FALSE
    )
  }
  y
}

#' Format a TEA report year as "YYYY-YY"
#'
#' @param year Ending calendar year.
#' @return Character scalar like `"2023-24"`.
#' @keywords internal
year_label <- function(year) {
  year <- as.integer(year)
  sprintf("%04d-%02d", year - 1L, year %% 100L)
}

#' Inverse of [year_label()]
#'
#' Accepts `"2023-24"` or `"2024"` and returns the integer ending year.
#' @keywords internal
year_from_label <- function(label) {
  label <- as.character(label)
  m <- regexec("(\\d{4})\\s*[\u2013-]\\s*(\\d{2})", label)
  parts <- regmatches(label, m)[[1]]
  if (length(parts) == 3L) {
    start <- as.integer(parts[2])
    suffix <- as.integer(parts[3])
    end <- (start %/% 100L) * 100L + suffix
    if (end < start) end <- end + 100L
    return(end)
  }
  m <- regmatches(label, regexpr("\\d{4}", label))
  if (!length(m)) return(NA_integer_)
  as.integer(m)
}

#' SHA-256 of a file
#' @keywords internal
sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

#' Map a file_format argument to a filename extension
#' @keywords internal
ext_for_format <- function(file_format) {
  switch(
    file_format,
    csv  = "csv",
    txt  = "dat",
    xlsx = "xlsx",
    file_format
  )
}

#' ISO-8601 UTC timestamp
#' @keywords internal
iso8601_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

#' Combine a sequence of path parts, skipping NULLs
#' @keywords internal
path_join <- function(...) {
  parts <- unlist(list(...), use.names = FALSE)
  parts <- parts[!is.null(parts) & nzchar(parts)]
  do.call(file.path, as.list(parts))
}
