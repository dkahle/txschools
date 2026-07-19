# Get the txschools cache directory

Honors `options("txschools.cache_dir")` if set (useful for tests and
air-gapped workflows). Otherwise falls back to
`tools::R_user_dir("txschools", "cache")`.

## Usage

``` r
txs_cache_dir()
```

## Value

Character scalar path; the directory is *not* created here.

## Examples

``` r
txs_cache_dir()
#> [1] "/Users/davidkahle/Library/Caches/org.R-project.R/R/txschools"
```
