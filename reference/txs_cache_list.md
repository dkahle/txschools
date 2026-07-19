# List cached files

Walks
[`txs_cache_dir()`](https://dkahle.github.io/txschools/reference/txs_cache_dir.md)
and reads every `*.txschools.yml` sidecar to return a tibble describing
the local cache.

## Usage

``` r
txs_cache_list()
```

## Value

A tibble (subclassed `txs_cache`, with a summary
[`print()`](https://rdrr.io/r/base/print.html)). Empty (with the
expected columns) if the cache is empty.
