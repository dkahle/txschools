# Download the TAPR variable dictionary

TEA publishes one "TAPR Data in Excel" workbook per year and level
(`TAPR_campus_2024.xlsx`, ...). Despite the billing, these workbooks are
variable dictionaries, not data: each sheet lists the variables of one
advanced-download dataset with its code and human-readable label. This
function downloads (and caches) the workbook and returns it as one tidy
tibble.

## Usage

``` r
txs_get_tapr_dictionary(
  year,
  level = c("campus", "district", "region", "state"),
  cache = TRUE,
  refresh = FALSE,
  timeout = 60,
  verbose = TRUE
)
```

## Arguments

- year:

  Integer ending year (e.g. `2024` for 2023-24).

- level:

  One of `"campus"`, `"district"`, `"region"`, `"state"`.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- timeout:

  HTTP timeout in seconds.

- verbose:

  Print progress messages.

## Value

A tibble with columns `year`, `school_year`, `level`, `sheet`,
`dataset`, `variable`, `label`, and a `txschools` attribute.

## Examples

``` r
if (FALSE) { # \dontrun{
dict <- txs_get_tapr_dictionary(2024, "campus")
dict[grepl("Attendance", dict$label), ]
} # }
```
