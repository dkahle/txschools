# Download school district property tax rates

Returns adopted maintenance-and-operations (M&O) and
interest-and-sinking (I&S) property-tax rates for every Texas school
district, by school year. Two public sources are merged: the Texas
Comptroller's annual "School District Tax Rates and Levies" workbooks
(tax years 2019 onward; the primary source), backfilled by TEA's
adopted-tax-rates workbook (school years 2005-06 onward) for years the
Comptroller does not cover – notably school year 2020-21, whose
Comptroller file was never published, and the pre-2019 history. A
`rate_source` column records which source each row came from.

## Usage

``` r
txs_get_tax_rates(
  years = NULL,
  mcr = NULL,
  cache = TRUE,
  refresh = FALSE,
  output = c("tidy", "raw"),
  timeout = 120,
  verbose = TRUE
)
```

## Arguments

- years:

  Integer vector of ending school years (2024 means 2023-24), or `NULL`
  for all available years.

- mcr:

  Optional Maximum Compressed Rate input: a data frame or a CSV path
  with columns (`year` or `school_year`, `district` or `cdn`, `mcr`).
  `NULL` leaves the `mcr` column `NA`.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- output:

  `"tidy"` (one typed row per district-year) or `"raw"` (the merged
  per-source rows as parsed, before renaming and the MCR join).

- timeout:

  Seconds per download; default 120.

- verbose:

  Print progress messages.

## Value

A tibble with columns `year`, `school_year`, `district` (6-digit
county-district number, zero-padded string), `district_name`, `mo_rate`,
`is_rate`, `total_rate`, `mcr`, `rate_source` (`"comptroller"` or
`"tea"`), and a `txschools` attribute.

## Details

Rates are dollars per \$100 of taxable value (`0.9134` means \$0.9134).
Districts that span counties appear once per county in the Comptroller
files with identical rates; they are de-duplicated to one row per
district-year.

## Maximum compressed rate

The golden/copper penny decomposition (see
[`txs_derive_pennies()`](https://dkahle.github.io/txschools/reference/txs_derive_pennies.md))
needs each district-year's Maximum Compressed Rate (MCR), and TEA
publishes no clean statewide MCR flat file: official values live in
per-district Summary of Finances reports (TEAL portal), "Final MCR and
Adoption of Tax Rate" TAA letters (PDF), and the planning "Tax Rate and
MCR Template" workbook. Until one of those is wired up, MCR is a
pluggable input: pass `mcr` a data frame or CSV path with columns
(`year` or `school_year`, `district` or `cdn`, `mcr`) and it is joined
in. Without it the `mcr` column is `NA` and the penny metrics from
[`txs_derive_pennies()`](https://dkahle.github.io/txschools/reference/txs_derive_pennies.md)
are `NA` too.

## Examples

``` r
if (FALSE) { # \dontrun{
rates <- txs_get_tax_rates(2024)
txs_get_tax_rates() |> txs_derive_pennies()
} # }
```
