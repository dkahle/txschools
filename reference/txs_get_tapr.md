# Download semantic TAPR datasets

Downloads public TAPR/TPRS HTML reports for one or more years and
geographies, then returns the report as a named list of semantic
datasets such as student grade distribution, ethnicity, sex, and other
cohorts. Use
[`txs_get_tapr_file()`](https://dkahle.github.io/txschools/reference/txs_get_tapr_file.md)
for the lower-level structured TAPR downloads.

## Usage

``` r
txs_get_tapr(
  year,
  level = c("campus", "district", "region", "state"),
  geography = NULL,
  datasets = NULL,
  cache = TRUE,
  refresh = FALSE,
  db = NULL,
  timeout = 60,
  verbose = TRUE
)
```

## Arguments

- year:

  Integer vector of ending years (e.g. `2025` for 2024-25).

- level:

  One of `"campus"`, `"district"`, `"region"`, `"state"`.

- geography:

  Character vector of campus, district, region, or state identifiers.
  For `level = "state"`, `NULL` uses `"000000000"`.

- datasets:

  Optional character vector of dataset keys from
  [`txs_list_tapr_datasets()`](https://dkahle.github.io/txschools/reference/txs_list_tapr_datasets.md).
  `NULL` requests all known keys.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- db:

  Optional DuckDB path or DBI connection. If supplied, the returned
  semantic tables are written to the database.

- timeout:

  HTTP timeout in seconds.

- verbose:

  Print progress messages.

## Value

A `tapr` named list of tibbles.
