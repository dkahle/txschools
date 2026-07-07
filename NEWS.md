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
