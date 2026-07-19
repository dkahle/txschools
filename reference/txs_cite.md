# Build a citation

Produces a [`utils::bibentry()`](https://rdrr.io/r/utils/bibentry.html)
suitable for printing or passing to
[`format()`](https://rdrr.io/r/base/format.html). If `x` is a tibble
returned by
[`txs_get_tapr_file()`](https://dkahle.github.io/txschools/reference/txs_get_tapr_file.md)
(or its sibling functions), the citation references that specific file
by source URL, retrieval timestamp, and short SHA-256 prefix. If `x` is
a semantic TAPR object from
[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md),
the citation references the semantic pull and its source pages.

## Usage

``` r
txs_cite(x = NULL, source = "tapr")
```

## Arguments

- x:

  Optional. A tibble returned by `txs_get_*()`. If `NULL`, returns a
  generic citation for the named `source`.

- source:

  `"tapr"`, `"src"`, `"aeis"`, or `"peims"`.

## Value

A `bibentry`.

## Examples

``` r
txs_cite(source = "tapr")
#> Texas Education Agency (2026). “Texas Academic Performance Reports.”
#> Public data; accessed via the txschools R package.,
#> <https://tea.texas.gov/texas-schools/accountability/academic-accountability/performance-reporting/texas-academic-performance-reports>.
```
