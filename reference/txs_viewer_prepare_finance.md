# Prepare data for the district viewer's Finance tab

Builds the baked artifact behind the viewer's optional Finance tab: a
district-level summary of PEIMS budget/actual data across the requested
school years, small enough to browse instantly once prepared. This is a
separate, optional step from
[`txs_viewer_prepare()`](https://dkahle.github.io/txschools/reference/txs_viewer_prepare.md)
– the Map and Compare tabs work without it – because it is meaningfully
slower: a district *actual* file is tens of millions of dollars across
millions of rows and several megabytes to download and parse, and this
fetches several such files. With the default scope (five school years,
both budget and actual, both districts and charters), expect roughly
10-20 minutes on first run; subsequent runs reuse each file's on-disk
cache.

## Usage

``` r
txs_viewer_prepare_finance(
  years = NULL,
  basis = c("actual", "budget"),
  dir = NULL,
  refresh = FALSE,
  verbose = TRUE
)
```

## Arguments

- years:

  Integer vector of ending school years; `NULL` (the default) resolves
  to the five most recent years
  [`txs_list_years()`](https://dkahle.github.io/txschools/reference/txs_list_years.md)
  reports for PEIMS.

- basis:

  Character vector: `"actual"`, `"budget"`, or both (default both) –
  unlike
  [`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md)'s
  single-choice `basis`, every requested value is fetched.

- dir:

  Output directory; default `file.path(txs_cache_dir(), "viewer")`,
  where
  [`txs_viewer()`](https://dkahle.github.io/txschools/reference/txs_viewer.md)
  looks.

- refresh:

  Ignore on-disk caches and refetch.

- verbose:

  Print progress.

## Value

Invisibly, a list with `dir`, `path`, `n_rows`, `years`, and the
combinations that succeeded/failed.

## Details

Each requested (year, basis, type) combination is fetched with
[`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md)
and campus-level detail (`fin_unit`, `campus_name`) is summed away – the
Finance tab draws district-wide flows, not per-campus ones – keeping
every other column (including the full fund/function/object/program code
detail
[`txs_peims_flow()`](https://dkahle.github.io/txschools/reference/txs_peims_flow.md)
needs for any axis combination). A combination TEA has not published yet
(e.g. the newest actual year) is skipped with a warning rather than
aborting the whole prepare.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_viewer_prepare_finance()
txs_viewer()
} # }
```
