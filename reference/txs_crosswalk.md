# Crosswalk TEA district numbers to NCES LEAIDs (Census GEOIDs)

Returns the Texas school-district crosswalk between TEA's six-digit
county-district number and the seven-digit NCES LEAID, which is also the
`GEOID` used by Census school-district boundary files (see
[`txs_boundaries()`](https://dkahle.github.io/txschools/reference/txs_boundaries.md)).
Built from the NCES CCD directory as served by the Urban Institute's
Education Data API (open, no key;
<https://educationdata.urban.org/documentation/school-districts.html>).

## Usage

``` r
txs_crosswalk(
  year = 2022,
  cache = TRUE,
  refresh = FALSE,
  timeout = 120,
  verbose = TRUE
)
```

## Arguments

- year:

  CCD directory vintage year available from the API.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- timeout:

  Seconds per request; default 120.

- verbose:

  Print progress messages.

## Value

A tibble with columns `geoid` (7-digit LEAID), `district` (6-digit TEA
county-district number), and `lea_name`, plus a `txschools` attribute.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_crosswalk() |> head()
} # }
```
