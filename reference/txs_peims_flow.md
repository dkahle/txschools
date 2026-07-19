# Build money-flow (Sankey) data from PEIMS finance rows

Aggregates a
[`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md)
result (typically filtered to one district) into the stage-to-stage edge
list behind an income-statement-style flow diagram: where the money came
from, which fund it moved through, and what it was spent on. Plot the
result with
[`txs_plot_peims_flow()`](https://dkahle.github.io/txschools/reference/txs_plot_peims_flow.md)
or any Sankey tool.

## Usage

``` r
txs_peims_flow(x, axes = c("source", "fund", "function"), lump = 5)
```

## Arguments

- x:

  A tibble from
  [`txs_get_peims_finance()`](https://dkahle.github.io/txschools/reference/txs_get_peims_finance.md)
  (tidy output), usually filtered to one district and year.

- axes:

  Character vector of two or more axes from the list above, in canonical
  order.

- lump:

  Maximum number of nodes per axis before smaller ones fold into an
  "Other ..." node (balance nodes excepted).

## Value

A tibble of class `peims_flow` with columns `from_axis`, `from`,
`to_axis`, `to`, `amount`, carrying the axis vector as an attribute.

## Axes and honesty

Available axes, in canonical order:

- `"source"` – revenue class from the object code: local (5700s), state
  (5800s), federal (5900s).

- `"fund"` – TEA fund (general fund, food service, Title I, ...).

- `"function"` – what the spending was for (instruction, ...).

- `"object"` – what was bought: payroll (6100s), contracted services
  (6200s), supplies (6300s), other operating (6400s), debt service
  (6500s), capital outlay (6600s).

- `"program"` – program intent (basic, special education, ...).

Every edge is a genuine total from the data: revenue rows record
(source, fund) jointly, and expenditure rows record (fund, function,
object, program) jointly. Because TEA does not record which revenue
dollar paid which bill, `"source"` may only be followed by `"fund"`
(money is only traceable source-to-spending *through* a fund);
requesting e.g. `c("source", "function")` errors.

## Fund balances

Funds rarely break even within a year. When `axes` starts at `"source"`,
each fund's shortfall is fed by a **"From fund balance"** node on the
source axis and each fund's surplus drains to a **"To fund balance"**
node on the following axis, so both sides of every fund reconcile
exactly.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_get_peims_finance(2024, "actual", "district") |>
  dplyr::filter(district == "161920") |>
  txs_peims_flow() |>
  txs_plot_peims_flow()
} # }
```
