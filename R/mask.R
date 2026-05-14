#' TEA masking and suppression values
#'
#' TEA suppresses small-cell statistics for FERPA compliance and uses a
#' small set of sentinel codes (e.g. `"."`, `"*"`, `"-1"`) to flag them.
#' `txschools` reads every value as character so these codes are never
#' silently coerced into numerics or `NA`.
#'
#' @section Default codes:
#' `.`, `*`, `-1`, `-2`, `-3`, `-4`, `-99`, `n/a`, `N/A`.
#'
#' @param x Character vector of values to check.
#' @param codes Character vector of values to treat as masked. Defaults
#'   to the package-wide list, configurable via the
#'   `txschools.mask_values` option.
#'
#' @return `is_masked()` returns a logical vector the same length as
#'   `x`. `mask_strip()` returns a [tibble::tibble()] with columns
#'   `value_num` (numeric, `NA` for masked rows), `masked` (logical),
#'   and `mask_code` (character, `NA` for non-masked rows).
#'
#' @examples
#' is_masked(c("12.3", "*", ".", "  -1 ", "100"))
#' mask_strip(c("12.3", "*", ".", "-1", "100"))
#' @export
is_masked <- function(x, codes = mask_codes()) {
  if (is.null(x)) return(logical(0))
  x_chr <- trimws(as.character(x))
  x_chr %in% codes
}

#' @rdname is_masked
#' @export
mask_strip <- function(x, codes = mask_codes()) {
  x_chr <- as.character(x)
  trimmed <- trimws(x_chr)
  masked <- trimmed %in% codes
  mask_code <- ifelse(masked, trimmed, NA_character_)
  num_input <- ifelse(masked, NA_character_, trimmed)
  num <- suppressWarnings(as.numeric(num_input))
  tibble::tibble(
    value_num = num,
    masked    = masked,
    mask_code = mask_code
  )
}

#' Currently configured masking codes
#'
#' Resolves the active mask-code vector, honoring
#' `options("txschools.mask_values")` if set.
#'
#' @keywords internal
#' @export
mask_codes <- function() {
  getOption("txschools.mask_values", default = TXS_MASK_VALUES)
}
