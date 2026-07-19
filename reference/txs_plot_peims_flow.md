# Plot a PEIMS money-flow diagram

Renders the edge list from
[`txs_peims_flow()`](https://dkahle.github.io/txschools/reference/txs_peims_flow.md)
as a Sankey diagram in the style of an income-statement flow chart,
using the ggsankey package (not on CRAN; install with
`remotes::install_github("davidsjoberg/ggsankey")`). Returns a ggplot,
so titles, themes, and
[`ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html) all
work as usual.

## Usage

``` r
txs_plot_peims_flow(
  flows,
  palette = NULL,
  unit = 10000,
  space = NULL,
  label_wrap = 16
)
```

## Arguments

- flows:

  A `peims_flow` tibble from
  [`txs_peims_flow()`](https://dkahle.github.io/txschools/reference/txs_peims_flow.md).

- palette:

  Optional named character vector of node colors, overriding the
  defaults (first- and last-axis nodes get color; middle-axis and
  balance nodes are neutral).

- unit:

  Dollars per ribbon strand; flows are drawn in units of `unit`
  (ggsankey sizes flows by row count). The default `1e4` keeps rendering
  exact to the nearest \$10,000.

- space:

  Vertical gap between nodes, in `unit`s. Default scales with the total
  flow.

- label_wrap:

  Width at which node labels wrap.

## Value

A ggplot object.
