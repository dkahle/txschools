# Delete cached files

Filter cached files by `source`/`year`/`level`/`data_type`/`dataset`/
`older_than` and delete them together with their sidecars. In
interactive sessions the user is prompted unless `ask = FALSE`. Pass
`all = TRUE` to wipe the entire cache (this ignores every other filter,
including `older_than`). Use
[`txs_cache_size()`](https://dkahle.github.io/txschools/reference/txs_cache_size.md)
with the same filters to preview what a delete would remove.

## Usage

``` r
txs_cache_delete(
  year = NULL,
  source = NULL,
  level = NULL,
  data_type = NULL,
  dataset = NULL,
  older_than = NULL,
  all = FALSE,
  ask = interactive()
)
```

## Arguments

- year:

  Optional ending year filter.

- source:

  Optional source filter (`"tapr"`, `"src"`, `"aeis"`, `"peims"`,
  `"taxrates"`, `"first"`, `"crosswalk"`, `"boundaries"`, `"viewer"`).

- level:

  Optional level filter (`"campus"`, `"district"`, …).

- data_type:

  Optional data-type filter (`"advanced"`, `"dictionary"`, `"report"`,
  …).

- dataset:

  Optional dataset-code filter (e.g. `"REF"`, `"STAAR1"`;
  case-insensitive).

- older_than:

  Optional cutoff: a `Date`/`POSIXct`, or a single number of days. Only
  files retrieved before the cutoff are deleted. Ignored when
  `all = TRUE`.

- all:

  If `TRUE`, ignore other filters and delete the whole cache.

- ask:

  Whether to confirm interactively. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

Invisibly returns a tibble of the rows that were deleted.
