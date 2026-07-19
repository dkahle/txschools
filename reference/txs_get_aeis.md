# Download an AEIS (Academic Excellence Indicator System) file

Downloads one statewide AEIS data file served by TEA's per-year download
CGI. Each file is identified by a level and a dataset code (e.g. `"ref"`
for reference information, `"stud"` for student information, `"fin"` for
finance); use
[`txs_list_downloads()`](https://dkahle.github.io/txschools/reference/txs_list_downloads.md)
to see the codes TEA publishes for a year.

## Usage

``` r
txs_get_aeis(
  year,
  level = c("campus", "district", "region", "state"),
  geography = NULL,
  dataset = "ref",
  layout = FALSE,
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
  the parsed file to. `NULL` returns all rows.

- dataset:

  AEIS dataset code, e.g. `"ref"`, `"stud"`, `"fin"`. Case-insensitive;
  defaults to `"ref"`.

- layout:

  If `TRUE`, also download the record layout (`.lyt`) for the dataset
  and attach it as `attr(out, "layout")` (a character vector of lines).

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

A tibble with a `txschools` attribute.

## Details

Coverage: this package supports the school years 2003-04 through 2011-12
(requested as ending years 2004 through 2012), the span TEA serves
through its AEIS download forms. TEA's AEIS archive pages reach further
back, but those years use different, unsupported publication formats.
