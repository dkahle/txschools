#' Download school district property tax rates
#'
#' Returns adopted maintenance-and-operations (M&O) and
#' interest-and-sinking (I&S) property-tax rates for every Texas school
#' district, by school year. Two public sources are merged: the Texas
#' Comptroller's annual "School District Tax Rates and Levies"
#' workbooks (tax years 2019 onward; the primary source), backfilled by
#' TEA's adopted-tax-rates workbook (school years 2005-06 onward) for
#' years the Comptroller does not cover -- notably school year 2020-21,
#' whose Comptroller file was never published, and the pre-2019
#' history. A `rate_source` column records which source each row came
#' from.
#'
#' Rates are dollars per $100 of taxable value (`0.9134` means
#' $0.9134). Districts that span counties appear once per county in the
#' Comptroller files with identical rates; they are de-duplicated to
#' one row per district-year.
#'
#' @section Maximum compressed rate:
#' The golden/copper penny decomposition (see [txs_derive_pennies()])
#' needs each district-year's Maximum Compressed Rate (MCR), and TEA
#' publishes no clean statewide MCR flat file: official values live in
#' per-district Summary of Finances reports (TEAL portal), "Final MCR
#' and Adoption of Tax Rate" TAA letters (PDF), and the planning "Tax
#' Rate and MCR Template" workbook. Until one of those is wired up, MCR
#' is a pluggable input: pass `mcr` a data frame or CSV path with
#' columns (`year` or `school_year`, `district` or `cdn`, `mcr`) and it
#' is joined in. Without it the `mcr` column is `NA` and the penny
#' metrics from [txs_derive_pennies()] are `NA` too.
#'
#' @param years Integer vector of ending school years (2024 means
#'   2023-24), or `NULL` for all available years.
#' @param mcr Optional Maximum Compressed Rate input: a data frame or a
#'   CSV path with columns (`year` or `school_year`, `district` or
#'   `cdn`, `mcr`). `NULL` leaves the `mcr` column `NA`.
#' @param output `"tidy"` (one typed row per district-year) or `"raw"`
#'   (the merged per-source rows as parsed, before renaming and the MCR
#'   join).
#' @inheritParams txs_get_peims_finance
#' @param timeout Seconds per download; default 120.
#' @return A tibble with columns `year`, `school_year`, `district`
#'   (6-digit county-district number, zero-padded string),
#'   `district_name`, `mo_rate`, `is_rate`, `total_rate`, `mcr`,
#'   `rate_source` (`"comptroller"` or `"tea"`), and a `txschools`
#'   attribute.
#' @examples
#' \dontrun{
#' rates <- txs_get_tax_rates(2024)
#' txs_get_tax_rates() |> txs_derive_pennies()
#' }
#' @export
txs_get_tax_rates <- function(years = NULL,
                              mcr = NULL,
                              cache = TRUE,
                              refresh = FALSE,
                              output = c("tidy", "raw"),
                              timeout = 120,
                              verbose = TRUE) {
  output <- match.arg(output)
  cache <- isTRUE(cache)
  cat_tax <- catalog_source("taxrates")
  if (is.null(years)) {
    years <- seq(
      TXS_FIRST_TAXRATES_YEAR,
      max(c(unlist(cat_tax$tea_years), unlist(cat_tax$comptroller_tax_years) + 1L))
    )
  }
  years <- vapply(years, normalize_year, integer(1), source = "taxrates")
  years <- sort(unique(years))

  files <- list()

  # Comptroller (primary), one workbook per tax year (= ending year - 1).
  # Attempt tax years the catalog lists as published, plus anything
  # newer than the catalog (so future releases are picked up); known
  # gaps like tax year 2020 are skipped without a 404 round trip.
  known_ty <- as.integer(unlist(cat_tax$comptroller_tax_years))
  try_year <- function(y) {
    ty <- y - 1L
    ty >= TXS_FIRST_COMPTROLLER_TAXYEAR &&
      (ty %in% known_ty || !length(known_ty) || ty > max(known_ty))
  }
  comp <- list()
  for (y in years[vapply(years, try_year, logical(1))]) {
    comp[[length(comp) + 1L]] <- tryCatch({
      dl <- taxrates_fetch_comptroller(y, cache = cache, refresh = refresh,
                                       timeout = timeout, verbose = verbose)
      files[[length(files) + 1L]] <- dl$meta
      parse_comptroller_rates(dl$path, year = y)
    }, error = function(e) {
      cli::cli_alert_warning(
        "Comptroller skip {year_label(y)}: {conditionMessage(e)}"
      )
      NULL
    })
  }
  comp <- dplyr::bind_rows(comp)

  # TEA adopted-rates workbook (backfill), one file for all years.
  tea <- tryCatch({
    dl <- taxrates_fetch_tea(cache = cache, refresh = refresh,
                             timeout = timeout, verbose = verbose)
    files[[length(files) + 1L]] <- dl$meta
    out <- parse_tea_adopted(dl$path)
    out[out$year %in% years, , drop = FALSE]
  }, error = function(e) {
    cli::cli_alert_warning("TEA backfill unavailable: {conditionMessage(e)}")
    NULL
  })

  rates <- merge_rate_sources(comp, tea)
  if (!nrow(rates)) {
    stop("No tax-rate data could be retrieved for the requested years.",
         call. = FALSE)
  }
  missing <- setdiff(years, unique(rates$year))
  if (length(missing)) {
    cli::cli_alert_warning(
      "No tax rates available for ending year{?s} {missing}."
    )
  }

  if (output == "raw") {
    out <- rates
  } else {
    mcr_tbl <- taxrates_resolve_mcr(mcr, years = years, verbose = verbose)
    out <- tibble::tibble(
      year          = rates$year,
      school_year   = vapply(rates$year, year_label, character(1)),
      district      = rates$cdn,
      district_name = rates$district_name,
      mo_rate       = rates$mo_rate,
      is_rate       = rates$is_rate,
      total_rate    = dplyr::coalesce(
        rates$total_rate_src,
        rates$mo_rate + dplyr::coalesce(rates$is_rate, 0)
      ),
      rate_source   = rates$source
    )
    out <- dplyr::left_join(out, mcr_tbl, by = c("year", "district"))
    if (!"mcr" %in% names(out)) out$mcr <- NA_real_
    out <- out[, c("year", "school_year", "district", "district_name",
                   "mo_rate", "is_rate", "total_rate", "mcr",
                   "rate_source")]
    out <- dplyr::arrange(out, .data$year, .data$district)
  }

  attr(out, "txschools") <- list(
    source = "taxrates", years = years,
    level = "district", data_type = "rates",
    files = files,
    retrieved_at = if (length(files)) files[[1]]$retrieved_at else NA_character_
  )
  out
}

# --- Downloads ---------------------------------------------------------------

# One Comptroller workbook per TAX year; school ending year y uses tax
# year y - 1. Returns list(path, meta).
taxrates_fetch_comptroller <- function(year, cache, refresh, timeout,
                                       verbose) {
  tax_year <- year - 1L
  url <- taxrates_comptroller_url(tax_year)
  filename <- sprintf("rates-levies-ty%d.%s", tax_year,
                      tools::file_ext(url))
  dest <- cache_path("taxrates", year, "district", "comptroller",
                     file = filename)
  if (!cache) dest <- temp_download_path(filename)
  taxrates_download(url, dest, source_meta = list(
    source = "taxrates", year = year, school_year = year_label(year),
    level = "district", data_type = "comptroller", dataset = NA_character_,
    file_format = "xlsx"
  ), cache = cache, refresh = refresh, timeout = timeout, verbose = verbose)
}

# The single TEA adopted-rates workbook (all years). Returns
# list(path, meta).
taxrates_fetch_tea <- function(cache, refresh, timeout, verbose) {
  dest <- cache_path("taxrates", year = NULL, data_type = "tea",
                     file = "school-district-adopted-tax-rates.xlsx")
  if (!cache) dest <- temp_download_path(basename(dest))
  taxrates_download(TXS_URL_TEA_ADOPTED_RATES, dest, source_meta = list(
    source = "taxrates", year = NA_integer_, school_year = NA_character_,
    level = "district", data_type = "tea", dataset = NA_character_,
    file_format = "xlsx"
  ), cache = cache, refresh = refresh, timeout = timeout, verbose = verbose)
}

# Shared download-or-cache step with sidecar provenance.
taxrates_download <- function(url, dest, source_meta, cache, refresh,
                              timeout, verbose) {
  if (cache && !refresh && file.exists(dest)) {
    if (verbose) cli::cli_alert_info("Using cached file: {dest}")
    meta <- read_sidecar(dest) %||% c(source_meta, list(
      source_url = url, retrieved_at = NA_character_,
      sha256 = sha256_file(dest), size_bytes = file.size(dest)
    ))
    return(list(path = dest, meta = meta))
  }
  if (verbose) cli::cli_alert_info("Downloading: {url}")
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  info <- http_download(url, dest, timeout = timeout, method = "get")
  meta <- c(source_meta, list(
    source_url = url, retrieved_at = info$retrieved_at,
    sha256 = info$sha256, size_bytes = info$size_bytes,
    content_type = info$content_type
  ))
  if (cache) write_sidecar(dest, meta)
  list(path = dest, meta = meta)
}

# --- Comptroller parsing (ported from txschoolviewer) ------------------------

taxrates_comptroller_url <- function(tax_year) {
  ext <- if (tax_year >= 2018) "xlsx" else "xls"
  sprintf(
    "https://comptroller.texas.gov/taxes/property-tax/docs/%d-school-district-rates-levies.%s",
    tax_year, ext
  )
}

# Normalize header text so layout drift between years matches: both
# "M & O Rate" (<= 2023) and "M&O RATE" (2024+) become "m&o rate".
norm_header <- function(x) gsub("\\s*&\\s*", "&", gsub("\\s+", " ", tolower(x)))

# Locate the header row by the (normalized) tokens it must contain.
find_header_row <- function(raw, must = c("taxing unit id", "m&o rate"),
                            max_scan = 30L) {
  n <- min(nrow(raw), max_scan)
  for (i in seq_len(n)) {
    cells <- norm_header(paste(unlist(raw[i, ]), collapse = " "))
    if (all(vapply(must, function(p) grepl(p, cells, fixed = TRUE),
                   logical(1)))) {
      return(i)
    }
  }
  1L
}

# County-district number from a Comptroller "Taxing Unit ID":
# "107-901-02" -> "107901".
cdn_from_taxing_unit_id <- function(x) {
  d <- gsub("\\D", "", as.character(x))
  out <- substr(d, 1L, 6L)
  out[nchar(out) != 6L] <- NA_character_
  out
}

parse_comptroller_rates <- function(path, year) {
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE,
                            .name_repair = "minimal")
  hdr <- find_header_row(raw)
  tab <- readxl::read_excel(path, sheet = 1, skip = hdr - 1L,
                            .name_repair = "unique")
  nm <- norm_header(names(tab))
  pick <- function(...) {
    pats <- c(...)
    idx <- which(Reduce(`|`, lapply(pats, function(p) {
      grepl(p, nm, fixed = TRUE)
    })))
    if (length(idx)) idx[[1]] else NA_integer_
  }
  i_id <- pick("taxing unit id")
  i_nm <- pick("taxing unit name")
  i_mo <- pick("m&o rate")
  i_is <- pick("i&s rate")
  i_tot <- pick("total tax rate")

  if (anyNA(c(i_id, i_mo, i_is))) {
    stop("Comptroller parse failed for ", basename(path),
         ". Detected headers: ", paste(names(tab), collapse = " | "),
         call. = FALSE)
  }

  out <- tibble::tibble(
    year = as.integer(year),
    cdn = cdn_from_taxing_unit_id(tab[[i_id]]),
    district_name = if (!is.na(i_nm)) as.character(tab[[i_nm]]) else NA_character_,
    mo_rate = suppressWarnings(as.numeric(tab[[i_mo]])),
    is_rate = suppressWarnings(as.numeric(tab[[i_is]])),
    total_rate_src = if (!is.na(i_tot)) {
      suppressWarnings(as.numeric(tab[[i_tot]]))
    } else {
      NA_real_
    },
    source = "comptroller"
  )
  out <- out[!is.na(out$cdn) & !is.na(out$mo_rate), , drop = FALSE]
  # Split districts repeat across counties with the same rate: keep one.
  dplyr::distinct(out, .data$cdn, .keep_all = TRUE)
}

# --- TEA adopted-rates parsing (ported from txschoolviewer) ------------------

parse_tea_adopted <- function(path) {
  tidy_tea_adopted(readxl::read_excel(path, sheet = 1))
}

# Reshape the wide TEA workbook (CDN, School District, then
# "<YYYY-YYYY> M&O Tax Rate" / "... I&S Tax Rate" pairs) into tidy
# district-year rows. Split from the file read for unit testing.
tidy_tea_adopted <- function(tab) {
  rate_cols <- grep("Tax Rate$", names(tab), value = TRUE)
  if (!length(rate_cols)) {
    stop("No '... Tax Rate' columns found. Detected: ",
         paste(names(tab), collapse = " | "), call. = FALSE)
  }
  long <- tidyr::pivot_longer(
    tab,
    cols = dplyr::all_of(rate_cols),
    names_to = c("sy_long", "rate_type"),
    names_pattern = "^(\\d{4}-\\d{4}) (M&O|I&S) Tax Rate$",
    values_to = "value"
  )
  long <- long[!is.na(long$rate_type), , drop = FALSE]
  wide <- tidyr::pivot_wider(
    long,
    id_cols = c("CDN", "School District", "sy_long"),
    names_from = "rate_type", values_from = "value"
  )
  out <- tibble::tibble(
    year = as.integer(substr(wide$sy_long, 1L, 4L)) + 1L,
    cdn = sprintf("%06d", as.integer(gsub("\\D", "", as.character(wide$CDN)))),
    district_name = as.character(wide[["School District"]]),
    mo_rate = suppressWarnings(as.numeric(wide[["M&O"]])),
    is_rate = suppressWarnings(as.numeric(wide[["I&S"]])),
    total_rate_src = NA_real_,
    source = "tea"
  )
  out[!is.na(out$cdn) & !is.na(out$mo_rate), , drop = FALSE]
}

# Comptroller wins any (year, cdn) overlap; TEA backfills the rest.
merge_rate_sources <- function(comp, tea) {
  rates <- dplyr::bind_rows(comp, tea)
  if (!nrow(rates)) return(rates)
  rates |>
    dplyr::mutate(
      src_rank = dplyr::if_else(.data$source == "comptroller", 1L, 2L)
    ) |>
    dplyr::arrange(.data$year, .data$cdn, .data$src_rank) |>
    dplyr::distinct(.data$year, .data$cdn, .keep_all = TRUE) |>
    dplyr::select(-"src_rank")
}

# --- MCR (pluggable input) ---------------------------------------------------

# Normalize a user-supplied MCR table (data frame or CSV path) to
# tibble(year, district, mcr); empty tibble when mcr is NULL.
taxrates_resolve_mcr <- function(mcr, years, verbose = TRUE) {
  empty <- tibble::tibble(
    year = integer(), district = character(), mcr = numeric()
  )
  if (is.null(mcr)) {
    if (verbose) {
      cli::cli_alert_info(paste(
        "No MCR input supplied; `mcr` will be NA and penny metrics",
        "blank. See ?txs_get_tax_rates."
      ))
    }
    return(empty)
  }
  raw <- if (is.character(mcr) && length(mcr) == 1L) {
    readr::read_csv(mcr, show_col_types = FALSE)
  } else if (is.data.frame(mcr)) {
    mcr
  } else {
    stop("`mcr` must be NULL, a data frame, or a CSV path.", call. = FALSE)
  }
  nm <- tolower(names(raw))
  names(raw) <- nm
  yr <- if ("year" %in% nm) {
    as.integer(raw$year)
  } else if ("school_year" %in% nm) {
    vapply(as.character(raw$school_year), year_from_label, integer(1))
  } else {
    stop("`mcr` needs a `year` or `school_year` column.", call. = FALSE)
  }
  dist <- if ("district" %in% nm) {
    raw$district
  } else if ("cdn" %in% nm) {
    raw$cdn
  } else {
    stop("`mcr` needs a `district` or `cdn` column.", call. = FALSE)
  }
  if (!"mcr" %in% nm) stop("`mcr` needs an `mcr` column.", call. = FALSE)
  tibble::tibble(
    year = yr,
    district = sprintf("%06d", as.integer(gsub("\\D", "", as.character(dist)))),
    mcr = as.numeric(raw$mcr)
  ) |>
    dplyr::filter(.data$year %in% years) |>
    dplyr::distinct(.data$year, .data$district, .keep_all = TRUE)
}

# --- Derived measures --------------------------------------------------------

#' Derive the golden/copper penny decomposition of the M&O rate
#'
#' Under HB3 (2019), a district's maintenance-and-operations tax effort
#' decomposes into **Tier One** (the Maximum Compressed Rate),
#' **golden pennies** (the first 8 cents of effort above the MCR --
#' highest yield, not subject to recapture), and **copper pennies**
#' (effort above the golden pennies -- lower yield, recaptured). All
#' rates are dollars per $100 of taxable value.
#'
#' @param x A data frame with numeric `mcr` and `mo_rate` columns (and
#'   optionally `is_rate`), one row per district-year -- typically from
#'   [txs_get_tax_rates()]. `NA` MCR (no MCR input supplied) yields
#'   `NA` penny metrics.
#' @param golden_cap Golden pennies cap in dollars per $100; 0.08 under
#'   current law.
#' @return `x` with added columns `tier_one_rate`, `golden_rate`,
#'   `copper_rate`, `enrichment_rate`, `golden_pennies`,
#'   `copper_pennies`, and (if absent) `total_rate`.
#' @examples
#' \dontrun{
#' txs_get_tax_rates(2024) |> txs_derive_pennies()
#' }
#' @export
txs_derive_pennies <- function(x, golden_cap = 0.08) {
  need <- c("mcr", "mo_rate")
  if (!all(need %in% names(x))) {
    stop("`x` must have columns: ", paste(need, collapse = ", "),
         ". Did it come from `txs_get_tax_rates()`?", call. = FALSE)
  }
  if (!"is_rate" %in% names(x)) x$is_rate <- NA_real_

  out <- dplyr::mutate(
    x,
    tier_one_rate = .data$mcr,
    golden_rate = pmin(pmax(.data$mo_rate - .data$mcr, 0), golden_cap),
    copper_rate = pmax(.data$mo_rate - .data$mcr - golden_cap, 0),
    enrichment_rate = .data$golden_rate + .data$copper_rate,
    # Pennies are whole cents of effort; round for display.
    golden_pennies = round(.data$golden_rate * 100),
    copper_pennies = round(.data$copper_rate * 100)
  )
  if (!"total_rate" %in% names(out)) {
    out$total_rate <- out$mo_rate + dplyr::coalesce(out$is_rate, 0)
  }
  out
}

#' Texas homestead exemption for school taxes, by year
#'
#' The state-mandated school-district homestead exemption in dollars,
#' by ending school year (the statute keys on the tax year, which is
#' the ending year minus one). Hard-coded schedule; verify when a
#' legislature changes it (the top value reflects the 2025 legislative
#' increase).
#'
#' @param year Integer ending school year(s); 2024 means the 2023-24
#'   school year (tax year 2023).
#' @return Numeric vector of exemption amounts in dollars.
#' @examples
#' txs_homestead_exemption(2024)
#' @export
txs_homestead_exemption <- function(year) {
  tax_year <- as.integer(year) - 1L
  dplyr::case_when(
    tax_year <= 2014 ~ 15000,
    tax_year <= 2021 ~ 25000,
    tax_year <= 2022 ~ 40000,
    tax_year <= 2024 ~ 100000,
    .default = 140000
  )
}
