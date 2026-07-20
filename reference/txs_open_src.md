# Open a campus or district's Texas School Report Card

Since 2020, TEA publishes School Report Cards exclusively at
<https://txschools.gov> – a JavaScript application this package cannot
scrape (see
[`txs_get_src()`](https://dkahle.github.io/txschools/reference/txs_get_src.md)
for the parsed 2004-2019 archive). This function is the complement for
anything
[`txs_get_src()`](https://dkahle.github.io/txschools/reference/txs_get_src.md)
cannot reach: it does not download or parse anything, it just launches
the right page in a browser.

## Usage

``` r
txs_open_src(
  geography,
  level = c("campus", "district"),
  tab = "overview",
  browse = TRUE
)
```

## Arguments

- geography:

  A single campus (9-digit) or district (6-digit) number, quoted to
  preserve leading zeros.

- level:

  `"campus"` or `"district"`.

- tab:

  Which tab of the report card to land on – TEA-defined, e.g.
  `"overview"`, `"academic"`, `"stakeholder-and-community-input"`, or
  (district level) `"schools"` to list its campuses.

- browse:

  If `TRUE` (the default), open the URL with
  [`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html). Set
  `FALSE` to only build the URL, e.g. for scripting or testing.

## Value

Invisibly, the URL.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_open_src("161920102")                     # China Spring Elementary
txs_open_src("161920", level = "district")     # China Spring ISD
} # }
```
