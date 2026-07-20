#' Prepare data for the district tax-rate viewer
#'
#' Builds the baked data artifacts behind [txs_viewer()]: statewide tax
#' rates (with the penny decomposition) joined to district boundaries
#' through the NCES crosswalk, written as a wide map table, a tidy long
#' table, and a small metadata file. Composes [txs_get_tax_rates()],
#' [txs_derive_pennies()], [txs_crosswalk()], and [txs_boundaries()] --
#' the first run downloads several files and takes a few minutes;
#' subsequent runs reuse the cache.
#'
#' @inheritParams txs_get_tax_rates
#' @param boundaries_year Census TIGER vintage for [txs_boundaries()].
#' @param dir Output directory; default `file.path(txs_cache_dir(),
#'   "viewer")`, where [txs_viewer()] looks.
#' @param verbose Print progress.
#' @return Invisibly, a list with `dir`, `paths`, and the metadata
#'   list.
#' @examples
#' \dontrun{
#' txs_viewer_prepare()
#' txs_viewer()
#' }
#' @export
txs_viewer_prepare <- function(years = NULL,
                               mcr = NULL,
                               boundaries_year = 2023,
                               dir = NULL,
                               refresh = FALSE,
                               verbose = TRUE) {
  for (pkg in c("sf", "tigris", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Package `", pkg, "` is required to prepare viewer data. ",
           'Install it with install.packages("', pkg, '").', call. = FALSE)
    }
  }
  dir <- dir %||% file.path(txs_cache_dir(), "viewer")

  rates <- txs_get_tax_rates(years = years, mcr = mcr, refresh = refresh,
                             verbose = verbose)
  rates <- txs_derive_pennies(rates)
  xwalk <- txs_crosswalk(refresh = refresh, verbose = verbose)
  bnd <- txs_boundaries(year = boundaries_year, refresh = refresh,
                        verbose = verbose)

  finance_long <- viewer_finance_long(rates, xwalk)
  paths <- viewer_build_artifact(bnd, finance_long, dir = dir)

  meta <- jsonlite::read_json(paths[["meta"]], simplifyVector = TRUE)
  if (verbose) {
    cli::cli_alert_success(paste(
      "Viewer data ready: {meta$n_districts_with_data} districts with",
      "data across {length(meta$school_years)} school years in {dir}"
    ))
  }
  invisible(list(dir = dir, paths = paths, meta = meta))
}

# Attach GEOIDs to the tidy rate table. Districts absent from the CCD
# crosswalk vintage are dropped (they cannot be drawn).
viewer_finance_long <- function(rates, xwalk) {
  rates |>
    dplyr::inner_join(
      dplyr::select(xwalk, "geoid", "district"),
      by = "district"
    ) |>
    dplyr::relocate("geoid") |>
    dplyr::arrange(.data$geoid, .data$year)
}

# Bake the three artifacts: districts.rds (wide sf, one column per
# metric-year), finance.rds (tidy long), meta.json. Sidecars make them
# visible to txs_cache_list()/txs_cache_delete(source = "viewer").
viewer_build_artifact <- function(boundaries, finance_long, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  metric_cols <- intersect(
    c("total_rate", "mo_rate", "is_rate", "mcr",
      "golden_rate", "copper_rate", "golden_pennies", "copper_pennies"),
    names(finance_long)
  )
  wide <- finance_long |>
    dplyr::mutate(yk = gsub("-", "_", .data$school_year)) |>
    tidyr::pivot_wider(
      id_cols = "geoid",
      names_from = "yk",
      values_from = dplyr::all_of(metric_cols),
      names_glue = "{.value}__{yk}"
    )

  districts <- boundaries |>
    dplyr::rename(district_name = "name") |>
    dplyr::left_join(wide, by = "geoid")

  paths <- c(
    districts = file.path(dir, "districts.rds"),
    finance = file.path(dir, "finance.rds"),
    meta = file.path(dir, "meta.json")
  )
  saveRDS(districts, paths[["districts"]])
  saveRDS(tibble::as_tibble(finance_long), paths[["finance"]])

  latest <- max(finance_long$school_year)
  meta <- list(
    built_at = iso8601_now(),
    school_years = sort(unique(finance_long$school_year)),
    metrics = c("total_rate", "mo_rate", "is_rate", "mcr", "golden_rate",
                "copper_rate", "golden_pennies", "copper_pennies"),
    n_districts_total = nrow(districts),
    n_districts_with_data = sum(!is.na(
      districts[[paste0("total_rate__", gsub("-", "_", latest))]]
    ))
  )
  jsonlite::write_json(meta, paths[["meta"]], auto_unbox = TRUE,
                       pretty = TRUE)

  for (p in paths[c("districts", "finance")]) {
    write_sidecar(p, list(
      source = "viewer", year = NA_integer_, school_year = NA_character_,
      level = "district", data_type = "artifact", dataset = NA_character_,
      file_format = "rds", source_url = NA_character_,
      retrieved_at = iso8601_now(), sha256 = sha256_file(p),
      size_bytes = file.size(p)
    ))
  }
  paths
}

#' Prepare data for the district viewer's Finance tab
#'
#' Builds the baked artifact behind the viewer's optional Finance tab: a
#' district-level summary of PEIMS budget/actual data across the
#' requested school years, small enough to browse instantly once
#' prepared. This is a separate, optional step from [txs_viewer_prepare()]
#' -- the Map and Compare tabs work without it -- because it is
#' meaningfully slower: a district *actual* file is tens of millions of
#' dollars across millions of rows and several megabytes to download and
#' parse, and this fetches several such files. With the default scope
#' (five school years, both budget and actual, both districts and
#' charters), expect roughly 10-20 minutes on first run; subsequent runs
#' reuse each file's on-disk cache.
#'
#' Each requested (year, basis, type) combination is fetched with
#' [txs_get_peims_finance()] and campus-level detail (`fin_unit`,
#' `campus_name`) is summed away -- the Finance tab draws district-wide
#' flows, not per-campus ones -- keeping every other column (including
#' the full fund/function/object/program code detail [txs_peims_flow()]
#' needs for any axis combination). A combination TEA has not published
#' yet (e.g. the newest actual year) is skipped with a warning rather
#' than aborting the whole prepare.
#'
#' @param years Integer vector of ending school years; `NULL` (the
#'   default) resolves to the five most recent years [txs_list_years()]
#'   reports for PEIMS.
#' @param basis Character vector: `"actual"`, `"budget"`, or both
#'   (default both) -- unlike [txs_get_peims_finance()]'s single-choice
#'   `basis`, every requested value is fetched.
#' @param dir Output directory; default `file.path(txs_cache_dir(),
#'   "viewer")`, where [txs_viewer()] looks.
#' @param refresh Ignore on-disk caches and refetch.
#' @param verbose Print progress.
#' @return Invisibly, a list with `dir`, `path`, `n_rows`, `years`, and
#'   the combinations that succeeded/failed.
#' @examples
#' \dontrun{
#' txs_viewer_prepare_finance()
#' txs_viewer()
#' }
#' @export
txs_viewer_prepare_finance <- function(years = NULL,
                                       basis = c("actual", "budget"),
                                       dir = NULL,
                                       refresh = FALSE,
                                       verbose = TRUE) {
  basis <- match.arg(basis, c("actual", "budget"), several.ok = TRUE)
  years <- years %||% utils::tail(sort(txs_list_years("peims")$year), 5L)
  dir <- dir %||% file.path(txs_cache_dir(), "viewer")

  combos <- expand.grid(
    year = years, basis = basis, type = c("district", "charter"),
    stringsAsFactors = FALSE
  )
  pulls <- vector("list", nrow(combos))
  ok <- character(0)
  failed <- character(0)
  for (i in seq_len(nrow(combos))) {
    yr <- combos$year[i]; bs <- combos$basis[i]; ty <- combos$type[i]
    label <- sprintf("%s %s %s", year_label(yr), ty, bs)
    pulls[[i]] <- tryCatch({
      out <- txs_get_peims_finance(yr, basis = bs, type = ty, labels = TRUE,
                                   refresh = refresh, verbose = verbose)
      ok <- c(ok, label)
      out
    }, error = function(e) {
      cli::cli_alert_warning("Skipping {label}: {conditionMessage(e)}")
      failed <<- c(failed, label)
      NULL
    })
  }

  rows <- dplyr::bind_rows(pulls)
  if (!nrow(rows)) {
    stop("No PEIMS data could be retrieved for the requested years/basis.",
         call. = FALSE)
  }
  summary <- rows |>
    dplyr::summarise(
      amount = sum(.data$amount),
      .by = c("district", "district_name", "year", "school_year", "basis",
              "type", "fund_code", "fund_label", "function_code",
              "function_label", "object_code", "object_label",
              "program_intent_code", "program_intent_label")
    )

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, "peims_summary.rds")
  saveRDS(summary, path)
  write_sidecar(path, list(
    source = "viewer", year = NA_integer_, school_year = NA_character_,
    level = "district", data_type = "peims_summary", dataset = NA_character_,
    file_format = "rds", source_url = NA_character_,
    retrieved_at = iso8601_now(), sha256 = sha256_file(path),
    size_bytes = file.size(path)
  ))

  if (verbose) {
    cli::cli_alert_success(paste(
      "Finance data ready: {nrow(summary)} rows across {length(ok)}",
      "year/basis/type combination{?s} in {path}"
    ))
    if (length(failed)) {
      cli::cli_alert_info("Skipped {length(failed)}: {paste(failed, collapse = ', ')}")
    }
  }
  invisible(list(dir = dir, path = path, n_rows = nrow(summary),
                years = years, combos_ok = ok, combos_failed = failed))
}

#' Launch the district tax-rate viewer
#'
#' An interactive slippy-map explorer of Texas school district property
#' tax rates: an animated choropleth (MapLibre via mapgl) with the M&O
#' rate decomposed into the Tier One compressed rate and golden/copper
#' pennies, district search, taxes-on-a-home mode, and a multi-district
#' comparison tab. Run [txs_viewer_prepare()] once first to bake the
#' data. If [txs_viewer_prepare_finance()] has also been run, a third
#' Finance tab shows an interactive PEIMS money-flow (Sankey) diagram
#' per district/year/basis; it needs the optional `ggsankey` package
#' and degrades gracefully (with an install hint) when that isn't
#' installed.
#'
#' @param dir Directory holding the prepared data; default
#'   `file.path(txs_cache_dir(), "viewer")`.
#' @param launch.browser Open in a browser (passed to
#'   [shiny::runApp()]).
#' @param ... Passed on to [shiny::runApp()].
#' @return Runs the app (blocking); returns whatever
#'   [shiny::runApp()] returns.
#' @examples
#' \dontrun{
#' txs_viewer_prepare()
#' txs_viewer()
#' }
#' @export
txs_viewer <- function(dir = NULL, launch.browser = TRUE, ...) {
  needed <- c("shiny", "bslib", "mapgl", "shinyWidgets", "plotly", "sf",
              "jsonlite")
  missing <- needed[!vapply(needed, requireNamespace, logical(1),
                            quietly = TRUE)]
  if (length(missing)) {
    stop(
      "The viewer needs package", if (length(missing) > 1) "s", " ",
      paste0("`", missing, "`", collapse = ", "), ".\nInstall with: ",
      sprintf('install.packages(c(%s))',
              paste0('"', missing, '"', collapse = ", ")),
      call. = FALSE
    )
  }
  dir <- dir %||% file.path(txs_cache_dir(), "viewer")
  artifacts <- file.path(dir, c("districts.rds", "finance.rds", "meta.json"))
  if (!all(file.exists(artifacts))) {
    stop(
      "No prepared viewer data in ", dir, ".\n",
      "Run `txs_viewer_prepare()` first (downloads several files; ",
      "takes a few minutes on the first run).",
      call. = FALSE
    )
  }

  old <- options(txschools.viewer_data_dir = dir)
  on.exit(options(old), add = TRUE)
  shiny::runApp(
    system.file("viewer", package = "txschools"),
    launch.browser = launch.browser, ...
  )
}
