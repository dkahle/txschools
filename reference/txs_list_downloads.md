# List downloads for a given year and source

Discovers data artifacts published for a particular TEA program year by
parsing the public HTML download pages, including the SAS-broker
download forms that serve the actual data files.

## Usage

``` r
txs_list_downloads(year, source = c("tapr", "aeis", "peims"), refresh = FALSE)
```

## Arguments

- year:

  Integer ending year.

- source:

  One of `"tapr"`, `"aeis"`, `"peims"`.

- refresh:

  If `TRUE`, ignore the on-disk meta cache and re-fetch.

## Value

A tibble with columns `source`, `year`, `school_year`, `level`,
`data_type`, `dataset`, `file_format`, `label`, `method`, `url`,
`params`.

## Details

For TAPR this returns:

- `data_type = "advanced"`: one row per level and dataset code
  (`dataset`, e.g. `"REF"`, `"STAAR1"`) served by TEA's SAS broker.
  These are the statewide data files (numerators, denominators, and
  rates).

- `data_type = "dictionary"`: the statewide variable-dictionary
  workbooks (`TAPR_campus_2024.xlsx`, ...). These describe variables;
  they do not contain data.

For AEIS this returns one row per level and dataset code served by the
per-year AEIS CGI. SRC is not a downloadable-file program; see
[`txs_get_src()`](https://dkahle.github.io/txschools/reference/txs_get_src.md).

For PEIMS this returns one row per financial single-file download:
`level` is `"district"` or `"charter"` and `data_type` is `"actual"` or
`"budget"`. See
[`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md).

## Examples

``` r
if (FALSE) { # \dontrun{
txs_list_downloads(2024, "tapr")
} # }
```
