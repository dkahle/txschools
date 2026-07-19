# Download PEIMS financial data (budget or actual)

Downloads one of TEA's PEIMS "single file" financial data downloads:
fund/function/object-level budget or actual financial data for all Texas
districts or all charter schools in one school year. These are statewide
bulk files (district actual files run to several million rows), not
per-campus reports.

## Usage

``` r
txs_get_peims_finance(
  year,
  basis = c("actual", "budget"),
  type = c("district", "charter"),
  labels = TRUE,
  cache = TRUE,
  refresh = FALSE,
  output = c("tidy", "raw"),
  keep_raw = FALSE,
  db = NULL,
  timeout = 300,
  verbose = TRUE
)
```

## Arguments

- year:

  Integer ending year (e.g. `2024` for 2023-24).

- basis:

  `"actual"` (audited actuals) or `"budget"` (adopted budgets).

- type:

  `"district"` (traditional districts) or `"charter"` (open-enrollment
  charter schools).

- labels:

  If `TRUE`, join human-readable labels for the
  fund/function/object/program-intent codes, plus district and campus
  names where available.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- output:

  `"tidy"` (typed, padded, labeled) or `"raw"` (all-character columns
  exactly as published).

- keep_raw:

  If `TRUE`, attach the raw parsed frame as `attr(out, "raw")`.

- db:

  Optional DuckDB file path or DBI connection. If supplied, the result
  is also written via
  [`txs_write_peims_db()`](https://dkahle.github.io/txschools/reference/txs_write_peims_db.md).

- timeout:

  Seconds; default 300 (district files are tens of MB).

- verbose:

  Print progress messages.

## Value

A tibble with a `txschools` attribute. Tidy columns: `district`,
`district_name`*, `fin_unit`, `campus_name`*, `year`, `school_year`,
`basis`, `type`, `fund_code`, `fund_label`*, `function_code`,
`function_label`*, `object_code`, `object_label`*,
`program_intent_code`, `program_intent_label`*, `amount`, `fiscal_year`,
`updated` (columns marked \* appear only when `labels = TRUE` succeeds
and TEA publishes the table).

## Coverage

School years 1999-2000 (requested as ending year 2000) through the
present. Actual data posts roughly a year after the fiscal year ends;
budget data for the upcoming school year posts before it starts.

## Granularity and labels

Rows are at the district x fund x function x object x fin-unit x
program-intent grain; `fin_unit` identifies the campus or organization
unit within the district. The raw files carry only codes. With
`labels = TRUE` (the default) the fund, function, object, and
program-intent code tables from TEA's companion "multiple file" budget
archive are joined in as `*_label` columns, along with district and
campus names where TEA publishes them. If the code tables cannot be
fetched, the data is returned with codes only, with a warning.

Charter files use TEA's nonprofit chart of accounts; their asset (fund),
function, object, and program-intent codes are normalized into the same
`fund_code`, `function_code`, `object_code`, and `program_intent_code`
columns.

No FERPA masking applies to this source: values are dollar amounts, not
student counts.

## Examples

``` r
if (FALSE) { # \dontrun{
act <- txs_get_peims_finance(2024, "actual", "district")
txs_get_peims_finance(2024, "budget", "charter", db = "peims.duckdb")
} # }
```
