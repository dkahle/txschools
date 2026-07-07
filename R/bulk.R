#' Plan a bulk download
#'
#' Builds a tibble row per `(year, level, dataset)` combination, with
#' the resolved URL/request, target cache path, and a flag indicating
#' whether the file is already cached.
#'
#' @param years Integer vector of ending years.
#' @param levels Character vector of levels.
#' @param datasets Character vector of TAPR advanced dataset codes
#'   (e.g. `c("REF", "STAAR1")`). `NULL` plans every dataset TEA
#'   publishes for the year/level.
#' @param data_type `"advanced"` (the statewide data files).
#' @return A tibble plan.
#' @examples
#' \dontrun{
#' plan <- txs_bulk_plan(2024, levels = "campus", datasets = c("REF", "GRAD"))
#' }
#' @export
txs_bulk_plan <- function(years,
                          levels = c("campus", "district"),
                          datasets = NULL,
                          data_type = "advanced") {
  years <- vapply(years, normalize_year, integer(1), source = "tapr")
  file_format <- "csv"
  source <- "tapr"
  if (!is.null(datasets)) datasets <- toupper(as.character(datasets))

  rows <- list()
  for (yr in years) {
    downloads <- tryCatch(
      txs_list_downloads(yr, source, refresh = FALSE),
      error = function(e) NULL
    )
    for (lvl in levels) {
      hit <- if (is.null(downloads) || !nrow(downloads)) {
        downloads_tibble(list())
      } else {
        downloads[
          downloads$level == lvl &
            downloads$data_type == data_type &
            downloads$file_format == file_format,
          , drop = FALSE
        ]
      }
      if (!is.null(datasets)) {
        hit <- hit[toupper(hit$dataset) %in% datasets, , drop = FALSE]
      }
      if (!nrow(hit)) {
        rows[[length(rows) + 1L]] <- tibble::tibble(
          source = source, year = yr, school_year = year_label(yr),
          level = lvl, data_type = data_type, dataset = NA_character_,
          file_format = file_format, method = NA_character_,
          url = NA_character_, params = NA_character_,
          cache_path = NA_character_, exists_in_cache = FALSE
        )
        next
      }
      for (i in seq_len(nrow(hit))) {
        h <- hit[i, , drop = FALSE]
        cp <- cache_path(source, yr, lvl, data_type,
                         file = download_filename(h))
        rows[[length(rows) + 1L]] <- tibble::tibble(
          source = source, year = yr, school_year = year_label(yr),
          level = lvl, data_type = data_type, dataset = h$dataset,
          file_format = file_format, method = h$method,
          url = h$url, params = h$params,
          cache_path = cp, exists_in_cache = file.exists(cp)
        )
      }
    }
  }
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
                              delay = 5,
                              refresh = FALSE,
                              stop_on_error = FALSE,
                              max_tries = 3) {
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
      info <- http_download(
        row$url, row$cache_path, max_tries = max_tries,
        method = row$method %||% "get", params = row$params
      )
      check_broker_data_response(row$cache_path, row)
      write_sidecar(row$cache_path, list(
        source       = row$source,
        year         = row$year,
        school_year  = row$school_year,
        level        = row$level,
        data_type    = row$data_type,
        dataset      = row$dataset,
        file_format  = row$file_format,
        source_url   = row$url,
        method       = row$method,
        params       = row$params,
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
