#' Plan a bulk download
#'
#' Builds a tibble row per `(year, level, data_type)` combination, with
#' the resolved URL, target cache path, and a flag indicating whether
#' the file is already cached.
#'
#' @param years Integer vector of beginning years.
#' @param levels Character vector of levels.
#' @param data_type `"rates"` or `"advanced"`.
#' @param file_format `"csv"`, `"txt"`, or `"xlsx"`.
#' @param source `"tapr"`, `"src"`, or `"aeis"`.
#' @return A tibble plan.
#' @examples
#' \dontrun{
#' plan <- txs_bulk_plan(2022:2023, levels = c("campus", "district"))
#' }
#' @export
txs_bulk_plan <- function(years,
                          levels = c("campus", "district"),
                          data_type = "advanced",
                          file_format = "csv",
                          source = "tapr") {
  years <- vapply(years, normalize_year, integer(1))
  grid <- expand.grid(
    year = years, level = levels, data_type = data_type,
    file_format = file_format, source = source,
    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE
  )

  rows <- lapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, , drop = FALSE]
    downloads <- tryCatch(
      txs_list_downloads(g$year, g$source, refresh = FALSE),
      error = function(e) NULL
    )
    if (is.null(downloads) || !nrow(downloads)) {
      return(tibble::tibble(
        source = g$source, year = g$year,
        school_year = year_label(g$year),
        level = g$level, data_type = g$data_type,
        file_format = g$file_format,
        url = NA_character_, cache_path = NA_character_,
        exists_in_cache = FALSE
      ))
    }
    hit <- downloads[
      downloads$level == g$level &
        downloads$data_type == g$data_type &
        downloads$file_format == g$file_format,
      , drop = FALSE
    ]
    url <- if (nrow(hit)) hit$url[1] else NA_character_
    cp  <- if (!is.na(url)) {
      cache_path(g$source, g$year, g$level, g$data_type,
                 file = basename(httr2::url_parse(url)$path))
    } else NA_character_
    tibble::tibble(
      source = g$source, year = g$year,
      school_year = year_label(g$year),
      level = g$level, data_type = g$data_type,
      file_format = g$file_format,
      url = url, cache_path = cp,
      exists_in_cache = !is.na(cp) && file.exists(cp)
    )
  })
  do.call(rbind, rows)
}

#' Execute a bulk-download plan
#'
#' Iterates over the rows of `plan` and downloads each file that is
#' not already cached (or all of them if `refresh = TRUE`). Sleeps
#' `delay` seconds between requests for politeness regardless of the
#' configured per-second rate limit.
#'
#' @param plan A tibble from [txs_bulk_plan()].
#' @param delay Seconds to sleep between non-cached requests.
#' @param refresh Re-download even if cached.
#' @param stop_on_error If `TRUE`, errors propagate; otherwise they are
#'   recorded in the `error` column and the loop continues.
#' @param max_tries Retry budget per request.
#' @return The plan with added columns `status`, `bytes`, `elapsed_s`,
#'   `sha256`, and `error`.
#' @export
txs_bulk_download <- function(plan,
                              delay = getOption("txschools.bulk_delay", 5),
                              refresh = FALSE,
                              stop_on_error = FALSE,
                              max_tries = TXS_MAX_TRIES) {
  if (!is.data.frame(plan) || !nrow(plan)) return(plan)
  n <- nrow(plan)
  status   <- character(n)
  bytes    <- rep(NA_real_, n)
  elapsed  <- rep(NA_real_, n)
  shas     <- rep(NA_character_, n)
  errors   <- rep(NA_character_, n)

  for (i in seq_len(n)) {
    row <- plan[i, , drop = FALSE]
    if (is.na(row$url)) {
      status[i] <- "no_url"; errors[i] <- "No URL resolved"
      next
    }
    if (!refresh && !is.na(row$cache_path) && file.exists(row$cache_path)) {
      status[i] <- "cached"
      bytes[i]  <- file.size(row$cache_path)
      shas[i]   <- sha256_file(row$cache_path)
      next
    }
    if (i > 1L) Sys.sleep(delay)
    t0 <- Sys.time()
    result <- tryCatch({
      dir.create(dirname(row$cache_path), recursive = TRUE, showWarnings = FALSE)
      info <- http_download(row$url, row$cache_path, max_tries = max_tries)
      write_sidecar(row$cache_path, list(
        source       = row$source,
        year         = row$year,
        school_year  = row$school_year,
        level        = row$level,
        data_type    = row$data_type,
        file_format  = row$file_format,
        source_url   = row$url,
        retrieved_at = info$retrieved_at,
        sha256       = info$sha256,
        size_bytes   = info$size_bytes,
        content_type = info$content_type
      ))
      list(ok = TRUE, sha = info$sha256, bytes = info$size_bytes)
    }, error = function(e) {
      if (isTRUE(stop_on_error)) stop(e)
      list(ok = FALSE, error = conditionMessage(e))
    })
    elapsed[i] <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (isTRUE(result$ok)) {
      status[i] <- "downloaded"
      bytes[i]  <- result$bytes
      shas[i]   <- result$sha
    } else {
      status[i] <- "error"
      errors[i] <- result$error
    }
  }
  plan$status    <- status
  plan$bytes     <- bytes
  plan$elapsed_s <- elapsed
  plan$sha256    <- shas
  plan$error     <- errors
  plan
}
