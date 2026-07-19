# Download a TAPR data file

Downloads (or returns the cached copy of) a single Texas Academic
Performance Reports statewide data file. TEA serves these through its
SAS-broker "Advanced Download" interface: one CSV per year, level, and
dataset code (e.g. `"REF"` for campus/district reference information,
`"STAAR1"` for STAAR performance). Use
[`txs_list_downloads()`](https://dkahle.github.io/txschools/reference/txs_list_downloads.md)
to see the codes available for a year, and
[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md)
for per-campus semantic datasets.

## Usage

``` r
txs_get_tapr_file(
  year,
  level = c("campus", "district", "region", "state"),
  geography = NULL,
  dataset = NULL,
  data_type = c("advanced", "rates"),
  file_format = c("csv", "txt", "xlsx", "html"),
  cache = TRUE,
  refresh = FALSE,
  output = c("tidy", "wide", "raw"),
  keep_raw = FALSE,
  timeout = 60,
  verbose = TRUE
)
```

## Arguments

- year:

  Integer ending year (e.g. `2024` for 2023-24).

- level:

  One of `"campus"`, `"district"`, `"region"`, `"state"`.

- geography:

  Optional. A character vector of campus or district numbers to filter
  the parsed file to. `NULL` returns all rows for statewide downloads.
  For `file_format = "html"`, supply exactly one campus, district, or
  region identifier.

- dataset:

  Dataset code for `data_type = "advanced"`, e.g. `"REF"`, `"STAAR1"`,
  `"GRAD"`. Case-insensitive. Required for advanced downloads; see
  [`txs_list_downloads()`](https://dkahle.github.io/txschools/reference/txs_list_downloads.md).

- data_type:

  `"advanced"` (the statewide data files: numerators, denominators, and
  rates) or `"rates"` (legacy static rates-only files, when TEA
  publishes them).

- file_format:

  `"csv"` (statewide files) or `"html"` (a public TAPR/TPRS report page
  for one requested geography).

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- output:

  `"tidy"` (long, masking-aware), `"wide"` (raw with human-readable
  labels attached), or `"raw"` (as parsed).

- keep_raw:

  If `TRUE`, attach the raw parsed frame as `attr(out, "raw")`.

- timeout:

  HTTP timeout in seconds.

- verbose:

  Print progress messages.

## Value

A tibble with a `txschools` attribute carrying source/metadata.
