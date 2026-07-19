# Package index

## Find schools and districts

Resolve names to TEA identifiers.

- [`txs_directory()`](https://dkahle.github.io/txschools/reference/txs_directory.md)
  : Texas school and district directory
- [`txs_find_campus()`](https://dkahle.github.io/txschools/reference/txs_find_campus.md)
  [`txs_find_district()`](https://dkahle.github.io/txschools/reference/txs_find_campus.md)
  : Find a campus or district by name

## Discovery

List the years and downloads that TEA publishes.

- [`txs_list_years()`](https://dkahle.github.io/txschools/reference/txs_list_years.md)
  : List the years available from a TEA source
- [`txs_list_downloads()`](https://dkahle.github.io/txschools/reference/txs_list_downloads.md)
  : List downloads for a given year and source

## Download

Download and parse public TEA data.

- [`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md)
  : Download semantic TAPR datasets
- [`txs_get_tapr_file()`](https://dkahle.github.io/txschools/reference/txs_get_tapr_file.md)
  : Download a TAPR data file
- [`txs_get_tapr_dictionary()`](https://dkahle.github.io/txschools/reference/txs_get_tapr_dictionary.md)
  : Download the TAPR variable dictionary
- [`txs_get_src()`](https://dkahle.github.io/txschools/reference/txs_get_src.md)
  : Download an SRC (School Report Card) report
- [`txs_get_aeis()`](https://dkahle.github.io/txschools/reference/txs_get_aeis.md)
  : Download an AEIS (Academic Excellence Indicator System) file
- [`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md)
  : Download PEIMS financial data (budget or actual)

## TAPR semantic datasets

Discover semantic TAPR table outputs.

- [`txs_list_tapr_datasets()`](https://dkahle.github.io/txschools/reference/txs_list_tapr_datasets.md)
  : List semantic TAPR datasets

## Databases

Write results to DuckDB for multi-year analysis.

- [`txs_write_tapr_db()`](https://dkahle.github.io/txschools/reference/txs_write_tapr_db.md)
  : Write semantic TAPR datasets to DuckDB
- [`txs_write_peims_db()`](https://dkahle.github.io/txschools/reference/txs_write_peims_db.md)
  : Write PEIMS financial data to DuckDB

## Cache

Manage the local file cache.

- [`txs_cache_dir()`](https://dkahle.github.io/txschools/reference/txs_cache_dir.md)
  : Get the txschools cache directory
- [`txs_cache_list()`](https://dkahle.github.io/txschools/reference/txs_cache_list.md)
  : List cached files
- [`txs_cache_size()`](https://dkahle.github.io/txschools/reference/txs_cache_size.md)
  : Summarize the size of the local cache
- [`txs_cache_delete()`](https://dkahle.github.io/txschools/reference/txs_cache_delete.md)
  : Delete cached files

## Bulk

Plan and execute multi-year, multi-level downloads.

- [`txs_bulk_plan()`](https://dkahle.github.io/txschools/reference/txs_bulk_plan.md)
  : Plan a bulk download
- [`txs_bulk_download()`](https://dkahle.github.io/txschools/reference/txs_bulk_download.md)
  : Execute a bulk-download plan

## Masking

Inspect TEA masking and suppression values.

- [`is_masked()`](https://dkahle.github.io/txschools/reference/is_masked.md)
  [`mask_strip()`](https://dkahle.github.io/txschools/reference/is_masked.md)
  : TEA masking and suppression values

## Citation

- [`txs_cite()`](https://dkahle.github.io/txschools/reference/txs_cite.md)
  : Build a citation
