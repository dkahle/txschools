# txschools 0.0.0.9000

* Initial scaffolding.
* TAPR public-data discovery, download, caching, and parsing.
* Tidy/wide/raw output shapes.
* Semantic TAPR table output via `txs_get_tapr()`, with legacy
  file-oriented TAPR access moved to `txs_get_tapr_file()`.
* Bulk plan and download workflow for multi-year studies.
* Citation helpers preserving exact retrieval timestamp, source URL, and SHA-256.

## Live-site rebuild (2026-07)

* Download discovery rebuilt against TEA's actual pages (verified live):
  `txs_list_downloads()` now parses the SAS-broker download forms and
  returns one row per level and dataset code, with the request method
  and parameters needed to execute it.
* `txs_get_tapr_file()` gains a `dataset` argument (e.g. `"REF"`,
  `"STAAR1"`) and downloads TEA's statewide advanced files through the
  broker (GET for 2024+, POST for earlier years). Broker "report page
  instead of data" responses are detected and raised as errors, never
  cached.
* New `txs_get_tapr_dictionary()`: the statewide `TAPR_*.xlsx`
  workbooks are variable dictionaries, not data; they are now parsed
  into one tidy code/label table.
* New `txs_directory()`, `txs_find_campus()`, `txs_find_district()`:
  name-to-identifier lookup built from TEA's statewide reference data.
* `txs_get_src()` rebuilt as a per-campus report pull (SRC has no bulk
  files): 2004-2012 campus reports are parsed from TEA's fixed-width
  HTML into tidy masking-aware tibbles; 2013-2019 reports are cached as
  the official PDFs; 2020+ points to txschools.gov.
* `txs_get_aeis()` rebuilt on TEA's per-year download CGI with a
  `dataset` argument (26 datasets per level) and optional record
  layouts.
* Masking hardening: values that fail numeric parsing (e.g. `"< 1%"`)
  are flagged as masked with the original marker preserved; display
  formatting (`%`, `$`, `,`) is stripped before parsing; generic TAPR
  page datasets keep the raw string in `value` alongside `value_num`.
* Entity names (campus/district/county) now parse correctly from live
  TAPR report pages.
* Per-source year validation (TAPR from 2013, AEIS 2004-2012, SRC
  2004-2019).
* Live smoke tests gated behind `TXS_LIVE=true` guard against TEA page
  drift.

## Review fixes (2026-07, after external code review)

* Masking fallback narrowed: only suppression-shaped markers
  (`"< 1%"`, `">99%"`, `"*"`, `"?"`, `"--"`) are flagged; year labels
  (`"2019-20"`) and grade spans (`"02 - 04"`) are ordinary text again.
* Numeric convention standardized and documented: `value_num` is always
  the number as printed (`"90%"` is 90); only the semantic student
  datasets' `*_percent` columns are proportions.
* Generic semantic datasets gain `section` and `row_index` columns:
  TEA's colspan section headings ("Grade 3 Reading") are now context on
  each row instead of duplicated pseudo-records.
* `txs_get_tapr()` warns (and records in the pages manifest) when a
  requested page cannot be retrieved, instead of returning silently
  empty datasets; one bad page no longer aborts a multi-page pull.
* `txs_get_tapr_file()` errors on the contradictory request
  `file_format = "html"` with an explicit `data_type = "advanced"`.
* The getting-started vignette no longer tangles live network/cache
  code, so `R CMD check` stays offline and never touches the user
  cache.

## Cache visibility tooling (2026-07)

* New `txs_cache_size()` summarizes cache size, optionally grouped `by`
  one or more of `source`, `year`, `level`, `data_type`, `dataset`.
* `txs_cache_size()` and `txs_cache_delete()` share one filter set --
  `source`/`year`/`level`/`data_type`/`dataset`/`older_than` (a `Date`,
  `POSIXct`, or a number of days) -- so a size preview always matches
  what the same delete call would remove. Files whose sidecars lack a
  retrieval timestamp are never matched by `older_than`.
* `txs_cache_list()` results now print a short summary header (file
  count, total size, retrieval date range when known) before the usual
  tibble output, and gain a `dataset` column.

## PEIMS finance (2026-07)

* New source: TEA's PEIMS "single file" financial data downloads.
  `txs_get_peims_finance(year, basis, type)` pulls one statewide
  fund/function/object-level budget or actual file for districts or
  charter schools, school years 1999-2000 onward -- the district actual
  files run to several million rows per year.
* The data arrives already long; the tidy output types the amounts,
  zero-pads the code columns, and (by default) joins human-readable
  fund/function/object/program-intent labels plus district and campus
  names from TEA's companion "multiple file" code tables, degrading
  gracefully to codes-only when those tables cannot be fetched.
  Charter files' nonprofit chart of accounts is normalized into the
  same columns.
* New `txs_write_peims_db()` writes results to DuckDB (one table per
  year/basis/type plus a `_peims_meta` provenance table), and the
  getter's `db` argument writes through directly, so multi-year
  databases build one call at a time. DBI/duckdb remain optional
  (Suggests).
* `txs_list_years()`, `txs_list_downloads()`, `txs_cite()`, and the
  cache tooling all understand `source = "peims"`. No FERPA masking
  applies to this source (amounts, not student counts).

## Data dictionary and duckplyr (2026-07)

* New machine-readable data dictionary at `inst/data-dict.yaml`
  (<https://data-dict.tidyverse.org> format, spec 0.1.0): documents
  every table the package returns -- the TAPR semantic shapes,
  statewide TAPR/AEIS files, the TAPR variable dictionary, SRC,
  the directory, and PEIMS finance (plus its DuckDB provenance
  table) -- with column types, ranges, masking semantics,
  cross-table relationships, and a glossary of TEA terms. Access it
  with `system.file("data-dict.yaml", package = "txschools")`.
* README's DuckDB section now also covers
  [duckplyr](https://duckplyr.tidyverse.org) as the no-database way
  to run dplyr pipelines on DuckDB's engine.

## PEIMS money-flow diagrams (2026-07)

* New `txs_peims_flow()`: aggregates a `txs_get_peims_finance()` pull
  into an income-statement-style flow edge list across chosen axes
  (revenue source, fund, function, object class, program intent).
  Every edge is a genuine recorded total -- sources trace to spending
  through funds, the one join TEA's accounting actually records --
  and each fund's shortfall/surplus reconciles against explicit
  from/to fund-balance nodes.
* New `txs_plot_peims_flow()`: renders the edge list as a Sankey
  diagram via the ggsankey package (GitHub-only; in Suggests with a
  guarded, informative error when absent). Returns a normal ggplot.
* New vignette `money-flow-diagrams`: the concepts behind honest
  money-flow charts (recorded joins vs allocation, funds as the
  traceable link, fund-balance reconciliation) and the same charts
  built with ggsankey, ggalluvial, plotly, and networkD3.

## Tax rates, geography, and the district viewer (2026-07)

* The txschoolviewer project is absorbed into txschools, including its
  uncommitted app improvements. Its targets pipeline is replaced by
  package getters + `txs_viewer_prepare()`; targets is not a
  dependency.
* New source `txs_get_tax_rates()`: district M&O/I&S property-tax
  rates, 2005-06 onward -- Texas Comptroller rates-and-levies
  workbooks (primary, tax years 2019+) backfilled by TEA's
  adopted-tax-rates workbook, with per-row provenance. MCR is a
  pluggable `mcr` argument pending an official statewide source;
  `txs_derive_pennies()` adds the HB3 Tier One/golden/copper
  decomposition and `txs_homestead_exemption()` the exemption
  schedule.
* New geography helpers: `txs_crosswalk()` (TEA district number to
  NCES LEAID/Census GEOID, via the Urban Institute Education Data
  API) and `txs_boundaries()` (simplified Census district boundaries
  via tigris/sf).
* New `txs_viewer()`: the interactive district tax-rate map explorer
  (MapLibre via mapgl; animated choropleth, district search,
  taxes-on-a-home mode, comparison tab), shipped in `inst/viewer/`
  with all app dependencies in Suggests. `txs_viewer_prepare()` bakes
  its data from the package getters into the cache.
* Follow-ups recorded, not implemented: wiring an official MCR
  source; a shinylive build of the viewer (geojson boundaries, no
  runtime sf); a viewer screenshot/vignette.

## TAPR attendance fix (2026-07)

* TEA's standalone TAPR attendance endpoint has never produced output;
  the `attendance` semantic dataset silently returned zero rows. It is
  now served as the attendance/absenteeism slice of TEA's combined
  attendance-graduation-dropout page (the `graduation` page), which is
  where TEA publishes those measures.
* The semantic page fetcher now detects SAS-broker error pages,
  refuses to cache them, warns like any other failed page, and treats
  previously cached error pages as stale (refetched automatically).

* New vignette `data-dictionaries`: human-readable documentation of
  every table the package returns, rendered directly from the shipped
  `data-dict.yaml` so the vignette and the machine-readable dictionary
  cannot drift apart.

## Finance tab for the district viewer (2026-07)

* New third tab in `txs_viewer()`: an interactive PEIMS money-flow
  (Sankey) diagram for any district or charter, with school-year,
  budget-vs-actual, axis-preset, and category-lumping controls. Uses
  the same `txs_peims_flow()`/`txs_plot_peims_flow()` as the README
  and vignette examples, so the look is consistent everywhere.
* New `txs_viewer_prepare_finance()`: a separate, optional bake step
  (default: last 5 school years, both budget and actual, both
  districts and charters) that fetches and aggregates PEIMS data away
  from campus-level (`fin_unit`) detail into a small district-wide
  summary, so the tab filters and redraws instantly with no live
  network calls. Slower than `txs_viewer_prepare()` (roughly 10-20
  minutes by default) and entirely optional -- the Map and Compare
  tabs work without it, and the Finance tab shows a plain instructional
  message rather than an error when it hasn't been run.
* The Finance tab's chart engine (`ggsankey`, GitHub-only) stays a
  *soft* dependency checked only where the tab renders -- it does not
  widen `txs_viewer()`'s hard package-guard list, so installing the
  viewer for the Map/Compare tabs never requires a non-CRAN package.
* Bug fix in `txs_peims_flow()`: the fund-balance/transfer
  reconciliation could error ("arguments must have same length") for
  any district-year with zero inter-fund transfers or zero other
  financing activity -- a common case, not an edge case -- because an
  internal label helper returned a stray length-1 value instead of
  `character(0)` on a zero-row input (a `base::paste()` recycling
  quirk). Fixed at the source; regression-tested.
