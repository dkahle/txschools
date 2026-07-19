# Download an SRC (School Report Card) report

TEA publishes the School Report Card as *per-campus (or district)
reports*, not as bulk data files. This function downloads one report
through TEA's public SAS-broker interface and, where TEA serves an HTML
report, parses it into a tidy masking-aware tibble.

## Usage

``` r
txs_get_src(
  year,
  level = c("campus", "district"),
  geography = NULL,
  format = c("auto", "html", "pdf"),
  cache = TRUE,
  refresh = FALSE,
  output = c("tidy", "raw"),
  timeout = 60,
  verbose = TRUE
)
```

## Arguments

- year:

  Integer ending year (e.g. `2024` for 2023-24).

- level:

  `"campus"` or `"district"`.

- geography:

  A single campus (9-digit) or district (6-digit) number, quoted to
  preserve leading zeros.

- format:

  `"auto"` (HTML when TEA offers it, else PDF), `"html"`, or `"pdf"`.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- output:

  For HTML reports: `"tidy"` (long, masking-aware) or `"raw"` (the
  report's text lines, one row per line).

- timeout:

  HTTP timeout in seconds.

- verbose:

  Print progress messages.

## Value

For HTML reports, a tibble with columns `year`, `school_year`, `level`,
`geography`, `school_name`, `district_name`, `page`, `section`,
`measure`, `row_label`, `column`, `value`, `value_num`, `masked`,
`mask_code`. For PDF reports, a one-row tibble with the cached file's
path and provenance. Both carry a `txschools` attribute.

## Coverage

- **2004-2012 campus reports** are available as HTML and are parsed into
  a tidy long tibble.

- **2004-2012 district reports and all 2013-2019 reports** are published
  by TEA as PDF only. These are downloaded to the cache and returned as
  a one-row tibble describing the file (see `Value`).

- **2020 and later** SRC reports live at <https://txschools.gov>, which
  this package does not scrape.

## Examples

``` r
if (FALSE) { # \dontrun{
src_2011 <- txs_get_src(2011, "campus", "161920102")
} # }
```
