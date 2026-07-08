#' Get the txschools cache directory
#'
#' Honors `options("txschools.cache_dir")` if set (useful for tests
#' and air-gapped workflows). Otherwise falls back to
#' `tools::R_user_dir("txschools", "cache")`.
#'
#' @return Character scalar path; the directory is *not* created here.
#' @examples
#' txs_cache_dir()
#' @export
txs_cache_dir <- function() {
  override <- getOption("txschools.cache_dir", default = NULL)
  if (!is.null(override) && nzchar(override)) {
    return(normalizePath(override, winslash = "/", mustWork = FALSE))
  }
  normalizePath(
    tools::R_user_dir("txschools", which = "cache"),
    winslash = "/",
    mustWork = FALSE
  )
}

# Build a deterministic path inside the cache for a (source, year, level,
# data_type, file) combination. `year` is the ending integer year.
cache_path <- function(source, year = NULL, level = NULL,
                       data_type = NULL, file = NULL) {
  parts <- list(txs_cache_dir(), source)
  if (!is.null(year))      parts <- c(parts, year_label(year))
  if (!is.null(level))     parts <- c(parts, level)
  if (!is.null(data_type)) parts <- c(parts, data_type)
  if (!is.null(file))      parts <- c(parts, file)
  do.call(file.path, parts)
}

# Sidecar metadata is written next to the cached file as `<file>.txschools.yml`.
sidecar_path <- function(path) paste0(path, ".txschools.yml")

# Human-readable byte sizes, built on base R's object_size formatter.
# vapply'd because format.object_size() isn't vectorized.
format_bytes <- function(x, standard = "SI") {
  vapply(x, function(b) {
    if (is.na(b)) return(NA_character_)
    format(structure(b, class = "object_size"), units = "auto", standard = standard)
  }, character(1))
}

# Inverse of iso8601_now(): parse a sidecar's retrieved_at back to POSIXct.
parse_retrieved_at <- function(x) {
  as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# Normalize an `older_than` argument (Date, POSIXct, or a number of days)
# into a POSIXct cutoff. Deliberately rejects strings: the package has no
# duration-parsing dependency and no precedent for relative-time DSLs.
resolve_older_than <- function(older_than) {
  if (is.null(older_than)) return(NULL)
  if (inherits(older_than, "POSIXct")) return(older_than)
  if (inherits(older_than, "Date")) return(as.POSIXct(older_than, tz = "UTC"))
  if (is.numeric(older_than) && length(older_than) == 1L && !is.na(older_than)) {
    return(Sys.time() - as.difftime(older_than, units = "days"))
  }
  stop(
    "`older_than` must be a Date, POSIXct, or a single number of days ",
    "(e.g. `older_than = 180`), not ", class(older_than)[1], ".",
    call. = FALSE
  )
}

as_txs_cache <- function(x) {
  class(x) <- c("txs_cache", class(x))
  x
}

temp_download_path <- function(filename) {
  ext <- tools::file_ext(filename)
  fileext <- if (nzchar(ext)) paste0(".", ext) else ""
  tempfile(pattern = "txschools-", tmpdir = tempdir(), fileext = fileext)
}

with_temporary_cache_dir <- function(expr) {
  old <- getOption("txschools.cache_dir", default = NULL)
  tmp <- tempfile("txschools-cache-")
  on.exit({
    options(txschools.cache_dir = old)
    unlink(tmp, recursive = TRUE)
  }, add = TRUE)
  options(txschools.cache_dir = tmp)
  force(expr)
}

write_sidecar <- function(path, meta) {
  meta$package_version <- as.character(utils::packageVersion("txschools"))
  meta$user_agent      <- getOption("txschools.user_agent", TXS_USER_AGENT_BASE)
  yaml::write_yaml(meta, sidecar_path(path))
  invisible(meta)
}

read_sidecar <- function(path) {
  s <- sidecar_path(path)
  if (!file.exists(s)) return(NULL)
  yaml::read_yaml(s)
}

#' List cached files
#'
#' Walks [txs_cache_dir()] and reads every `*.txschools.yml` sidecar to
#' return a tibble describing the local cache.
#'
#' @return A tibble (subclassed `txs_cache`, with a summary `print()`).
#'   Empty (with the expected columns) if the cache is empty.
#' @export
txs_cache_list <- function() {
  root <- txs_cache_dir()
  empty <- tibble::tibble(
    source       = character(),
    year         = integer(),
    school_year  = character(),
    level        = character(),
    data_type    = character(),
    dataset      = character(),
    file_format  = character(),
    file         = character(),
    size_bytes   = double(),
    sha256       = character(),
    retrieved_at = character(),
    source_url   = character(),
    path         = character()
  )
  if (!dir.exists(root)) return(as_txs_cache(empty))
  sidecars <- list.files(
    root, pattern = "\\.txschools\\.yml$",
    recursive = TRUE, full.names = TRUE
  )
  if (!length(sidecars)) return(as_txs_cache(empty))

  rows <- lapply(sidecars, function(s) {
    meta <- tryCatch(yaml::read_yaml(s), error = function(e) NULL)
    if (is.null(meta)) return(NULL)
    data_path <- sub("\\.txschools\\.yml$", "", s)
    tibble::tibble(
      source       = meta$source %||% NA_character_,
      year         = as.integer(meta$year %||% NA_integer_),
      school_year  = meta$school_year %||% NA_character_,
      level        = meta$level %||% NA_character_,
      data_type    = meta$data_type %||% NA_character_,
      dataset      = meta$dataset %||% NA_character_,
      file_format  = meta$file_format %||% NA_character_,
      file         = basename(data_path),
      size_bytes   = as.numeric(meta$size_bytes %||% NA_real_),
      sha256       = meta$sha256 %||% NA_character_,
      retrieved_at = meta$retrieved_at %||% NA_character_,
      source_url   = meta$source_url %||% NA_character_,
      path         = data_path
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(as_txs_cache(empty))
  as_txs_cache(do.call(rbind, rows))
}

# Shared inventory filter for txs_cache_size()/txs_cache_delete(), so
# "preview" and "delete" always agree on what a filter selects. Files
# whose sidecar lacks a retrieval timestamp are never matched by
# `older_than` (unknown provenance is kept, conservatively).
filter_cache_inventory <- function(inv, source = NULL, year = NULL,
                                   level = NULL, data_type = NULL,
                                   dataset = NULL, older_than = NULL) {
  cutoff <- resolve_older_than(older_than)
  if (!is.null(source))    inv <- inv[inv$source %in% source, , drop = FALSE]
  if (!is.null(year))      inv <- inv[inv$year %in% as.integer(year), , drop = FALSE]
  if (!is.null(level))     inv <- inv[inv$level %in% level, , drop = FALSE]
  if (!is.null(data_type)) inv <- inv[inv$data_type %in% data_type, , drop = FALSE]
  if (!is.null(dataset)) {
    inv <- inv[!is.na(inv$dataset) &
                 toupper(inv$dataset) %in% toupper(dataset), , drop = FALSE]
  }
  if (!is.null(cutoff)) {
    keep <- !is.na(inv$retrieved_at) &
      parse_retrieved_at(inv$retrieved_at) < cutoff
    inv <- inv[keep, , drop = FALSE]
  }
  inv
}

#' Summarize the size of the local cache
#'
#' @param source,year,level,data_type,dataset Optional filters, same
#'   semantics as [txs_cache_delete()].
#' @param older_than Optional cutoff: a `Date`/`POSIXct`, or a single
#'   number of days. When given, only files retrieved before the
#'   cutoff are counted; useful for previewing what
#'   `txs_cache_delete(older_than = )` would remove.
#' @param by `NULL`, or one or more of `"source"`, `"year"`, `"level"`,
#'   `"data_type"`, `"dataset"`. When given, returns one row per group
#'   (entries missing that field are grouped under `NA`, not dropped).
#' @return A tibble with `n_files`, `size_bytes`, and a human-readable
#'   `size` column, plus the grouping column(s) if `by` is given.
#' @examples
#' txs_cache_size()
#' @export
txs_cache_size <- function(source = NULL, year = NULL, level = NULL,
                           data_type = NULL, dataset = NULL,
                           older_than = NULL, by = NULL) {
  inv <- filter_cache_inventory(
    txs_cache_list(),
    source = source, year = year, level = level,
    data_type = data_type, dataset = dataset, older_than = older_than
  )

  by_choices <- c("source", "year", "level", "data_type", "dataset")
  if (!is.null(by)) by <- match.arg(by, by_choices, several.ok = TRUE)

  summarize_rows <- function(df) {
    tibble::tibble(n_files = nrow(df), size_bytes = sum(df$size_bytes, na.rm = TRUE))
  }

  if (is.null(by)) {
    out <- summarize_rows(inv)
  } else if (!nrow(inv)) {
    group_template <- lapply(by, function(b) if (identical(b, "year")) integer() else character())
    names(group_template) <- by
    out <- do.call(
      tibble::tibble,
      c(group_template, list(n_files = integer(), size_bytes = double()))
    )
  } else {
    # paste() turns NA into the literal string "NA", so missing values
    # form their own group instead of being dropped by split().
    key <- do.call(paste, c(as.list(inv[by]), list(sep = "\x1f")))
    out <- do.call(rbind, lapply(split(seq_len(nrow(inv)), key), function(idx) {
      df <- inv[idx, , drop = FALSE]
      cbind(df[1L, by, drop = FALSE], summarize_rows(df))
    }))
    rownames(out) <- NULL
    out <- tibble::as_tibble(out)
  }

  out$size <- format_bytes(out$size_bytes)
  out
}

#' Delete cached files
#'
#' Filter cached files by `source`/`year`/`level`/`data_type`/`dataset`/
#' `older_than` and delete them together with their sidecars. In
#' interactive sessions the user is prompted unless `ask = FALSE`. Pass
#' `all = TRUE` to wipe the entire cache (this ignores every other
#' filter, including `older_than`). Use [txs_cache_size()] with the
#' same filters to preview what a delete would remove.
#'
#' @param year Optional ending year filter.
#' @param source Optional source filter (`"tapr"`, `"src"`, `"aeis"`).
#' @param level Optional level filter (`"campus"`, `"district"`, …).
#' @param data_type Optional data-type filter (`"advanced"`,
#'   `"dictionary"`, `"report"`, …).
#' @param dataset Optional dataset-code filter (e.g. `"REF"`,
#'   `"STAAR1"`; case-insensitive).
#' @param older_than Optional cutoff: a `Date`/`POSIXct`, or a single
#'   number of days. Only files retrieved before the cutoff are
#'   deleted. Ignored when `all = TRUE`.
#' @param all If `TRUE`, ignore other filters and delete the whole cache.
#' @param ask Whether to confirm interactively. Defaults to
#'   [interactive()].
#' @return Invisibly returns a tibble of the rows that were deleted.
#' @export
txs_cache_delete <- function(year = NULL, source = NULL, level = NULL,
                             data_type = NULL, dataset = NULL,
                             older_than = NULL, all = FALSE,
                             ask = interactive()) {
  inv <- txs_cache_list()

  if (isTRUE(all)) {
    root <- txs_cache_dir()
    if (!dir.exists(root)) return(invisible(inv))
    if (isTRUE(ask)) {
      cli::cli_alert_warning("About to delete the entire txschools cache.")
      ans <- utils::menu(c("Yes", "No"), title = "Proceed?")
      if (ans != 1L) {
        cli::cli_alert_info("Aborted; nothing deleted.")
        return(invisible(inv[0, , drop = FALSE]))
      }
    }
    unlink(root, recursive = TRUE)
    cli::cli_alert_success("Deleted the txschools cache.")
    return(invisible(inv))
  }

  # Validate older_than even when the cache is empty.
  resolve_older_than(older_than)
  if (!nrow(inv)) return(invisible(inv))

  target <- filter_cache_inventory(
    inv,
    source = source, year = year, level = level,
    data_type = data_type, dataset = dataset, older_than = older_than
  )
  if (!nrow(target)) {
    cli::cli_alert_info("No cached files matched the filter.")
    return(invisible(target))
  }
  if (isTRUE(ask)) {
    cli::cli_alert_warning("About to delete {nrow(target)} cached file{?s}.")
    ans <- utils::menu(c("Yes", "No"), title = "Proceed?")
    if (ans != 1L) {
      cli::cli_alert_info("Aborted; nothing deleted.")
      return(invisible(target[0, , drop = FALSE]))
    }
  }
  for (p in target$path) {
    unlink(p)
    unlink(sidecar_path(p))
  }
  # Also clean up empty leaf directories.
  prune_empty_dirs(txs_cache_dir())
  cli::cli_alert_success("Deleted {nrow(target)} cached file{?s}.")
  invisible(target)
}

# Bottom-up empty-directory pruning.
prune_empty_dirs <- function(root) {
  if (!dir.exists(root)) return(invisible(NULL))
  dirs <- list.dirs(root, recursive = TRUE, full.names = TRUE)
  # Descend deepest-first so children get checked before parents.
  dirs <- dirs[order(-nchar(dirs))]
  for (d in dirs) {
    if (identical(normalizePath(d), normalizePath(root))) next
    if (!length(list.files(d, all.files = TRUE, no.. = TRUE))) {
      unlink(d, recursive = TRUE)
    }
  }
  invisible(NULL)
}

#' @export
print.txs_cache <- function(x, ...) {
  n <- nrow(x)
  cat("<txs_cache: ", n, " file", if (n == 1L) "" else "s",
      ", ", format_bytes(sum(x$size_bytes, na.rm = TRUE)), ">\n", sep = "")
  ts <- parse_retrieved_at(x$retrieved_at)
  if (any(!is.na(ts))) {
    rng <- range(ts, na.rm = TRUE)
    cat("retrieved: ", format(rng[1], "%Y-%m-%d"), " to ",
        format(rng[2], "%Y-%m-%d"), "\n", sep = "")
  }
  NextMethod()
}
