#' Read a TAPR/SRC/AEIS file as all-character columns
#'
#' Reads with everything as character so masking codes like `"*"`,
#' `"."`, `"-1"` survive the parse intact. Numeric coercion happens
#' only in `to_tidy()` and [mask_strip()].
#'
#' For `.zip` files (TEA frequently distributes a zipped bundle), the
#' archive is extracted alongside the zip and the contained data file
#' is parsed.
#'
#' @keywords internal
read_tapr_file <- function(path, file_format = NULL) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "zip") {
    extracted <- unzip_one(path)
    return(read_tapr_file(extracted, file_format = file_format))
  }
  fmt <- file_format %||% switch(
    ext, csv = "csv", txt = "txt", dat = "txt",
    xls = "xlsx", xlsx = "xlsx",
    "csv"
  )
  switch(
    fmt,
    csv  = read_tapr_csv(path),
    txt  = read_tapr_txt(path),
    xlsx = read_tapr_xlsx(path),
    stop("Unsupported file_format: ", fmt, call. = FALSE)
  )
}

unzip_one <- function(zip_path) {
  out_dir <- paste0(zip_path, "-unzipped")
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip_path, exdir = out_dir)
  }
  files <- list.files(out_dir, recursive = TRUE, full.names = TRUE)
  # Prefer csv > dat > txt; fall back to first file.
  pick <- function(re) files[grep(re, files, ignore.case = TRUE)]
  csv <- pick("\\.csv$")
  if (length(csv)) return(csv[1])
  dat <- pick("\\.dat$")
  if (length(dat)) return(dat[1])
  txt <- pick("\\.txt$")
  if (length(txt)) return(txt[1])
  if (length(files)) return(files[1])
  stop("Empty zip archive: ", zip_path, call. = FALSE)
}

read_tapr_csv <- function(path) {
  # All character; do not interpret any value as NA. trim_ws keeps mask
  # codes intact (".", "*").
  tibble::as_tibble(readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    trim_ws = TRUE,
    progress = FALSE
  ))
}

read_tapr_txt <- function(path) {
  # Sniff first non-empty line to decide on delimiter.
  con <- file(path, "r")
  on.exit(close(con), add = TRUE)
  line <- ""
  while (length(line) && !nzchar(line)) line <- readLines(con, n = 1L)
  if (!length(line) || !nzchar(line)) {
    return(tibble::tibble())
  }
  sep <- if (grepl(",", line)) "," else if (grepl("\t", line)) "\t" else "|"
  tibble::as_tibble(readr::read_delim(
    path,
    delim = sep,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    trim_ws = TRUE,
    progress = FALSE
  ))
}

read_tapr_xlsx <- function(path) {
  tibble::as_tibble(readxl::read_excel(
    path,
    col_types = "text",
    .name_repair = "minimal"
  ))
}
