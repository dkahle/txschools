# Download TEA's FIRST financial integrity ratings

Returns the Financial Integrity Rating System of Texas (FIRST) ratings
TEA assigns every school district (School FIRST) and open-enrollment
charter (Charter FIRST): one row per district or charter per rating
year, with its pass/fail status, rating, letter grade, and score. TEA
publishes these only through two public search apps, not as files; each
statewide workbook is fetched from those apps on demand and cached like
any other download.

## Usage

``` r
txs_get_first(
  years,
  type = c("district", "charter"),
  cache = TRUE,
  refresh = FALSE,
  output = c("tidy", "raw"),
  timeout = 60,
  verbose = TRUE
)
```

## Arguments

- years:

  Integer vector of ending rating years (2026 means the 2025-26
  ratings). Required.

- type:

  `"district"` (School FIRST), `"charter"` (Charter FIRST, including
  university charters), or both (the default).

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- output:

  `"tidy"` (one typed row per district or charter and rating year) or
  `"raw"` (TEA's columns as published, all character, after `year`,
  `list`, and `tea_title` columns).

- timeout:

  Seconds per request; default 60.

- verbose:

  Print progress messages.

## Value

A tibble with columns `year`, `school_year`, `fiscal_year`, `type`
(`"district"` or `"charter"`), `university_charter`, `district` (6-digit
district number, zero-padded string), `district_name`, `region` (2-digit
ESC region), `status`, `rating`, `grade`, `score`, `release`
(`"preliminary"` or `"final"`), and `last_updated` (Date), plus a
`txschools` attribute recording each workbook's provenance.

## Years

`years` are ending *rating* years, matching TEA's labels: `2026` means
the 2025-26 FIRST ratings, which TEA computes from fiscal-year 2025
(2024-25 school year) financial data. The `fiscal_year` column
(`year - 1`) joins the rated data to PEIMS actuals, e.g.
`txs_get_peims_finance(2025, "actual")`.

## Coverage

School FIRST covers 2002-03 onward and Charter FIRST 2011-12 onward.
Since 2017-18 TEA rates university charters pass/fail in a separate
list; those rows have `type = "charter"`, `university_charter = TRUE`,
and no score. TEA's public site has no separate university list before
2017-18.

The rating system changed over time, so compare `rating` and `score`
within an era:

- 2002-03 to 2013-14: "Superior Achievement", "Above Standard
  Achievement", "Standard Achievement", "Substandard Achievement" (plus
  "Suspended: ..." and, for charters, "Undetermined"); scores out of 65
  to 85 points depending on the year.

- 2014-15: pass/fail only ("Pass" or "Substandard Achievement"), scored
  out of 30.

- 2015-16 onward: letter grades out of 100 points, "A = Superior"
  through "F = Substandard Achievement" (worded "A = Superior
  Achievement" from 2020-21; Charter FIRST writes "A - ..."). The
  `grade` column holds the letter for these years and is `NA` before.

## Preliminary and final ratings

TEA posts preliminary ratings in August and final ratings, after
appeals, by mid-November. Charter FIRST labels its workbooks
accordingly, but School FIRST labels every workbook "Final". The
`release` column therefore follows TEA's label for charters and marks a
district workbook `"preliminary"` when it was downloaded before December
1 of the rating year. Cached copies are never replaced silently: once
finals post, re-run with `refresh = TRUE` (the function reminds you when
a cached copy predates them).

## How it is fetched

Each (rating year, list) workbook takes one short session against TEA's
search app, at one request per second: three requests for the district
or charter list, four for the university-charter list. The full history,
`txs_get_first(2003:2026)`, is about 150 requests on first use and free
afterwards.

## Examples

``` r
if (FALSE) { # \dontrun{
first <- txs_get_first(2026)
txs_get_first(2020:2026, type = "district") |>
  dplyr::filter(district == "161920")
} # }
```
