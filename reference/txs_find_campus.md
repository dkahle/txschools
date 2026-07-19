# Find a campus or district by name

Case-insensitive pattern search over the TEA directory built by
[`txs_directory()`](https://dkahle.github.io/txschools/reference/txs_directory.md).
Returns matching rows with the quoted identifiers expected by
[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md),
[`txs_get_src()`](https://dkahle.github.io/txschools/reference/txs_get_src.md),
and
[`txs_get_aeis()`](https://dkahle.github.io/txschools/reference/txs_get_aeis.md).

## Usage

``` r
txs_find_campus(
  pattern,
  year = NULL,
  cache = TRUE,
  refresh = FALSE,
  verbose = FALSE
)

txs_find_district(
  pattern,
  year = NULL,
  cache = TRUE,
  refresh = FALSE,
  verbose = FALSE
)
```

## Arguments

- pattern:

  A regular expression (case-insensitive) matched against
  campus/district names. For campuses, the district name is searched
  too, so `txs_find_campus("china spring")` returns every campus in
  China Spring ISD.

- year:

  Integer ending year of the TAPR reference file to use. `NULL`
  (default) uses the most recent year that resolves.

- cache, refresh, verbose:

  Passed to the underlying download; see
  [`txs_get_tapr_file()`](https://dkahle.github.io/txschools/reference/txs_get_tapr_file.md).

## Value

A tibble; see
[`txs_directory()`](https://dkahle.github.io/txschools/reference/txs_directory.md).

## Examples

``` r
if (FALSE) { # \dontrun{
txs_find_campus("china spring")
txs_find_district("waco")
} # }
```
