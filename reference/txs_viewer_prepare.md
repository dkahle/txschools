# Prepare data for the district tax-rate viewer

Builds the baked data artifacts behind
[`txs_viewer()`](https://dkahle.github.io/txschools/reference/txs_viewer.md):
statewide tax rates (with the penny decomposition) joined to district
boundaries through the NCES crosswalk, written as a wide map table, a
tidy long table, and a small metadata file. Composes
[`txs_get_tax_rates()`](https://dkahle.github.io/txschools/reference/txs_get_tax_rates.md),
[`txs_derive_pennies()`](https://dkahle.github.io/txschools/reference/txs_derive_pennies.md),
[`txs_crosswalk()`](https://dkahle.github.io/txschools/reference/txs_crosswalk.md),
and
[`txs_boundaries()`](https://dkahle.github.io/txschools/reference/txs_boundaries.md)
– the first run downloads several files and takes a few minutes;
subsequent runs reuse the cache.

## Usage

``` r
txs_viewer_prepare(
  years = NULL,
  mcr = NULL,
  boundaries_year = 2023,
  dir = NULL,
  refresh = FALSE,
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

- boundaries_year:

  Census TIGER vintage for
  [`txs_boundaries()`](https://dkahle.github.io/txschools/reference/txs_boundaries.md).

- dir:

  Output directory; default `file.path(txs_cache_dir(), "viewer")`,
  where
  [`txs_viewer()`](https://dkahle.github.io/txschools/reference/txs_viewer.md)
  looks.

- refresh:

  If `TRUE`, re-download even if cached.

- verbose:

  Print progress.

## Value

Invisibly, a list with `dir`, `paths`, and the metadata list.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_viewer_prepare()
txs_viewer()
} # }
```
