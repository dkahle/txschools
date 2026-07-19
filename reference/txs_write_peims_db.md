# Write PEIMS financial data to DuckDB

Writes a tibble returned by
[`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md)
to a DuckDB database (or any DBI connection) as a table named
`peims_finance_<basis>_<type>_<year>`, and appends a provenance row to a
`_peims_meta` table. Calling this once per year/basis/type builds a
multi-year database suitable for `dbplyr` aggregation.

## Usage

``` r
txs_write_peims_db(x, db, overwrite = FALSE)
```

## Arguments

- x:

  A tibble from
  [`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md).

- db:

  A DuckDB file path or an existing DBI connection.

- overwrite:

  If `TRUE`, replace an existing table with the same name.

## Value

Invisibly returns `x`.

## Examples

``` r
if (FALSE) { # \dontrun{
act <- txs_get_peims_finance(2024, "actual", "district")
txs_write_peims_db(act, "peims.duckdb")
} # }
```
