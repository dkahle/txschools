# Read the bundled URL/source catalog

Returns the parsed catalog as a list. The catalog is a hand-authored
YAML file (`inst/extdata/source_catalog.yml`) that documents the
TAPR/SRC/AEIS/PEIMS/tax-rate/FIRST base URLs, known years, and filename
patterns. It is the fallback that `discover_*` functions consult when
live HTML parsing fails or `refresh = FALSE`.

## Usage

``` r
txs_catalog()
```
