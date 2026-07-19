# Summarize the size of the local cache

Summarize the size of the local cache

## Usage

``` r
txs_cache_size(
  source = NULL,
  year = NULL,
  level = NULL,
  data_type = NULL,
  dataset = NULL,
  older_than = NULL,
  by = NULL
)
```

## Arguments

- source, year, level, data_type, dataset:

  Optional filters, same semantics as
  [`txs_cache_delete()`](https://dkahle.github.io/txschools/reference/txs_cache_delete.md).

- older_than:

  Optional cutoff: a `Date`/`POSIXct`, or a single number of days. When
  given, only files retrieved before the cutoff are counted; useful for
  previewing what `txs_cache_delete(older_than = )` would remove.

- by:

  `NULL`, or one or more of `"source"`, `"year"`, `"level"`,
  `"data_type"`, `"dataset"`. When given, returns one row per group
  (entries missing that field are grouped under `NA`, not dropped).

## Value

A tibble with `n_files`, `size_bytes`, and a human-readable `size`
column, plus the grouping column(s) if `by` is given.

## Examples

``` r
txs_cache_size()
#> # A tibble: 1 × 3
#>   n_files size_bytes size    
#>     <int>      <dbl> <chr>   
#> 1     171  408449717 408.4 MB
```
