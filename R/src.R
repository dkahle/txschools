#' Download an SRC (School Report Card) file
#'
#' @inheritParams txs_get_tapr
#' @return A tibble with a `txschools` attribute.
#' @export
txs_get_src <- function(year,
                        level,
                        geography = NULL,
                        data_type = c("rates"),
                        file_format = c("csv", "txt", "xlsx"),
                        cache = TRUE,
                        refresh = FALSE,
                        output = c("tidy", "wide", "raw"),
                        keep_raw = FALSE,
                        timeout = 60,
                        verbose = TRUE) {
  data_type   <- match.arg(data_type)
  file_format <- match.arg(file_format)
  output      <- match.arg(output)
  level       <- match.arg(level, c("campus", "district", "region", "state"))

  generic_get(
    source = "src", year = year, level = level, geography = geography,
    data_type = data_type, file_format = file_format,
    cache = cache, refresh = refresh, output = output,
    keep_raw = keep_raw, timeout = timeout, verbose = verbose
  )
}
