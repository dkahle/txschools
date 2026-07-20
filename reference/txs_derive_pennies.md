# Derive the golden/copper penny decomposition of the M&O rate

Under HB3 (2019), a district's maintenance-and-operations tax effort
decomposes into **Tier One** (the Maximum Compressed Rate), **golden
pennies** (the first 8 cents of effort above the MCR – highest yield,
not subject to recapture), and **copper pennies** (effort above the
golden pennies – lower yield, recaptured). All rates are dollars per
\$100 of taxable value.

## Usage

``` r
txs_derive_pennies(x, golden_cap = 0.08)
```

## Arguments

- x:

  A data frame with numeric `mcr` and `mo_rate` columns (and optionally
  `is_rate`), one row per district-year – typically from
  [`txs_get_tax_rates()`](https://dkahle.github.io/txschools/reference/txs_get_tax_rates.md).
  `NA` MCR (no MCR input supplied) yields `NA` penny metrics.

- golden_cap:

  Golden pennies cap in dollars per \$100; 0.08 under current law.

## Value

`x` with added columns `tier_one_rate`, `golden_rate`, `copper_rate`,
`enrichment_rate`, `golden_pennies`, `copper_pennies`, and (if absent)
`total_rate`.

## Examples

``` r
if (FALSE) { # \dontrun{
txs_get_tax_rates(2024) |> txs_derive_pennies()
} # }
```
