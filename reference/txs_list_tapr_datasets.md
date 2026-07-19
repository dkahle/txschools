# List semantic TAPR datasets

Returns the stable dataset keys that
[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md)
can return.

## Usage

``` r
txs_list_tapr_datasets()
```

## Value

A tibble with columns `key`, `label`, `page_source`, `grain`, and
`columns`.

## Numeric conventions

Columns named `*_percent` hold proportions (`"49.6%"` parses to
`0.496`). Every other numeric column – including the generic datasets'
`value_num` – holds the number as printed by TEA (`"90%"` parses to
`90`, `"$4,668"` to `4668`).
