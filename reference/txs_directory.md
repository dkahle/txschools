# Texas school and district directory

Builds a searchable directory of Texas campuses or districts – names,
TEA identifiers, districts, counties, regions, and grade spans – from
the statewide TAPR reference dataset (`REF`), the same public file TEA
serves through its Advanced Download interface. Use it to look up the
nine-digit campus (or six-digit district) numbers that
[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md)
and friends require.

## Usage

``` r
txs_directory(
  year = NULL,
  level = c("campus", "district"),
  cache = TRUE,
  refresh = FALSE,
  timeout = 60,
  verbose = TRUE
)
```

## Arguments

- year:

  Integer ending year of the TAPR reference file to use. `NULL`
  (default) uses the most recent year that resolves.

- level:

  `"campus"` or `"district"`.

- cache, refresh, timeout, verbose:

  Passed to the underlying download; see
  [`txs_get_tapr_file()`](https://dkahle.github.io/txschools/reference/txs_get_tapr_file.md).

## Value

A tibble with columns `year`, `level`, `id`, `name`, `district`,
`district_name`, `county_name`, `region`, and `grade_span` (columns not
published for a level are `NA`). Identifiers are character vectors to
preserve leading zeros.

## See also

[`txs_find_campus()`](https://dkahle.github.io/txschools/reference/txs_find_campus.md),
[`txs_find_district()`](https://dkahle.github.io/txschools/reference/txs_find_campus.md)

## Examples

``` r
if (FALSE) { # \dontrun{
txs_directory(2024, "campus")
} # }
```
