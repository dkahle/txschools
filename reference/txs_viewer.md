# Launch the district tax-rate viewer

An interactive slippy-map explorer of Texas school district property tax
rates: an animated choropleth (MapLibre via mapgl) with the M&O rate
decomposed into the Tier One compressed rate and golden/copper pennies,
district search, taxes-on-a-home mode, and a multi-district comparison
tab. Run
[`txs_viewer_prepare()`](https://dkahle.github.io/txschools/reference/txs_viewer_prepare.md)
once first to bake the data.

## Usage

``` r
txs_viewer(dir = NULL, launch.browser = TRUE, ...)
```

## Arguments

- dir:

  Directory holding the prepared data; default
  `file.path(txs_cache_dir(), "viewer")`.

- launch.browser:

  Open in a browser (passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)).

- ...:

  Passed on to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Runs the app (blocking); returns whatever
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html) returns.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_viewer_prepare()
txs_viewer()
} # }
```
