# Plan a bulk download

Builds a tibble row per `(year, level, dataset)` combination, with the
resolved URL/request, target cache path, and a flag indicating whether
the file is already cached.

## Usage

``` r
txs_bulk_plan(
  years,
  levels = c("campus", "district"),
  datasets = NULL,
  data_type = "advanced"
)
```

## Arguments

- years:

  Integer vector of ending years.

- levels:

  Character vector of levels.

- datasets:

  Character vector of TAPR advanced dataset codes (e.g.
  `c("REF", "STAAR1")`). `NULL` plans every dataset TEA publishes for
  the year/level.

- data_type:

  `"advanced"` (the statewide data files).

## Value

A tibble plan.

## Examples

``` r
if (FALSE) { # \dontrun{
plan <- txs_bulk_plan(2024, levels = "campus", datasets = c("REF", "GRAD"))
} # }
```
