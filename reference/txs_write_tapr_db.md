# Write semantic TAPR datasets to DuckDB

Write semantic TAPR datasets to DuckDB

## Usage

``` r
txs_write_tapr_db(x, db, overwrite = FALSE)
```

## Arguments

- x:

  A `tapr` object returned by
  [`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md).

- db:

  A DuckDB file path or an existing DBI connection.

- overwrite:

  If `TRUE`, replace existing tables with the same names.

## Value

Invisibly returns `x`.
