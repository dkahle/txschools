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
#' @return A tibble. Empty (with the expected columns) if the cache is
#'   empty.
#' @export
txs_cache_list <- function() {
  root <- txs_cache_dir()
  empty <- tibble::tibble(
    source       = character(),
    year         = integer(),
    school_year  = character(),
    level        = character(),
    data_type    = character(),
    file_format  = character(),
    file         = character(),
    size_bytes   = double(),
    sha256       = character(),
    retrieved_at = character(),
    source_url   = character(),
    path         = character()
  )
  if (!dir.exists(root)) return(empty)
  sidecars <- list.files(
    root, pattern = "\\.txschools\\.yml$",
    recursive = TRUE, full.names = TRUE
  )
  if (!length(sidecars)) return(empty)

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
  if (!length(rows)) return(empty)
  do.call(rbind, rows)
}

#' Delete cached files
#'
#' Filter cached files by `source`/`year`/`level` and delete them
#' together with their sidecars. In interactive sessions the user is
#' prompted unless `ask = FALSE`. Pass `all = TRUE` to wipe the entire
#' cache.
#'
#' @param year Optional ending year filter.
#' @param source Optional source filter (`"tapr"`, `"src"`, `"aeis"`).
#' @param level Optional level filter (`"campus"`, `"district"`, …).
#' @param all If `TRUE`, ignore other filters and delete the whole cache.
#' @param ask Whether to confirm interactively. Defaults to
#'   [interactive()].
#' @return Invisibly returns a tibble of the rows that were deleted.
#' @export
txs_cache_delete <- function(year = NULL, source = NULL, level = NULL,
                             all = FALSE, ask = interactive()) {
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

  if (!nrow(inv)) return(invisible(inv))

  target <- inv
  if (!is.null(source)) target <- target[target$source %in% source, , drop = FALSE]
  if (!is.null(year))   target <- target[target$year   %in% as.integer(year), , drop = FALSE]
  if (!is.null(level))  target <- target[target$level  %in% level, , drop = FALSE]
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
