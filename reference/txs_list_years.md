# List the years available from a TEA source

For TAPR, scrapes the public TEA TAPR landing page; for AEIS and SRC,
returns the archive years documented in the bundled catalog (verified
against TEA's site), augmented by live scraping where possible.

## Usage

``` r
txs_list_years(source = c("tapr", "src", "aeis", "peims"), refresh = FALSE)
```

## Arguments

- source:

  One of `"tapr"`, `"src"`, `"aeis"`, `"peims"`.

- refresh:

  If `TRUE`, ignore the on-disk meta cache and re-fetch.

## Value

A tibble with columns `source`, `year`, `school_year`.

## Details

Results are cached per session under `txs_cache_dir()/_meta/`. Pass
`refresh = TRUE` to force a re-fetch.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_list_years("tapr")
} # }
```
