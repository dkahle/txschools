# Output shape transforms. All three take a raw all-character tibble
# and metadata; they differ in how columns are laid out and whether
# masking is separated from numeric values.

to_raw <- function(df) df

to_wide <- function(df, year, level) {
  # Wide passthrough with a small `labels` attribute that maps known
  # variable codes to human-readable names. The codebook (hand-authored)
  # lives in inst/extdata/tapr_var_codes.csv when available.
  labels <- variable_codebook()
  if (length(labels)) {
    attr(df, "labels") <- labels[names(df)]
  }
  df
}

to_tidy <- function(df, year, level) {
  key_cols <- detect_key_cols(df, level)
  value_cols <- setdiff(names(df), key_cols)
  if (!length(value_cols)) return(df)

  long <- tidyr::pivot_longer(
    df,
    cols = dplyr::all_of(value_cols),
    names_to = "variable_code",
    values_to = "value",
    values_transform = list(value = as.character)
  )
  ms <- mask_strip(long$value)
  long$value_num <- ms$value_num
  long$masked    <- ms$masked
  long$mask_code <- ms$mask_code
  long$year      <- as.integer(year)
  long$school_year <- year_label(year)
  long$level     <- level
  # Reorder for readability.
  front <- c(key_cols, "year", "school_year", "level",
             "variable_code", "value", "value_num", "masked", "mask_code")
  long[, c(intersect(front, names(long)),
           setdiff(names(long), front)), drop = FALSE]
}

# Heuristic detection of "key" (identifier) columns. The TAPR files
# follow predictable naming conventions for campus/district numbers.
detect_key_cols <- function(df, level) {
  nms <- names(df)
  candidates <- c(
    "CAMPUS", "CAMPNAME", "CAMPUS_NAME", "CAMPUS_NUMBER",
    "DISTRICT", "DISTNAME", "DISTRICT_NAME", "DISTRICT_NUMBER",
    "REGION", "ESC_REGION",
    "GRADE", "GRDTYPE", "GRDSPAN"
  )
  hit <- intersect(toupper(candidates), toupper(nms))
  # Map back to original casing.
  nms[toupper(nms) %in% hit]
}

# Optional bundled variable codebook (NOT TEA data; this is a
# package-authored mapping of variable code patterns to descriptions).
variable_codebook <- function() {
  p <- system.file("extdata", "tapr_var_codes.csv", package = "txschools")
  if (!nzchar(p) || !file.exists(p)) return(stats::setNames(character(0), character(0)))
  cb <- tryCatch(
    utils::read.csv(p, stringsAsFactors = FALSE, na.strings = ""),
    error = function(e) NULL
  )
  if (is.null(cb) || !all(c("code", "label") %in% names(cb))) {
    return(stats::setNames(character(0), character(0)))
  }
  out <- as.character(cb$label)
  names(out) <- as.character(cb$code)
  out
}
