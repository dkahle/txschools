# TEA masking and suppression values

TEA suppresses small-cell statistics for FERPA compliance and uses a
small set of sentinel codes (e.g. `"."`, `"*"`, `"-1"`) to flag them.
`txschools` reads every value as character so these codes are never
silently coerced into numerics or `NA`.

## Usage

``` r
is_masked(x, codes = mask_codes())

mask_strip(x, codes = mask_codes())
```

## Arguments

- x:

  Character vector of values to check.

- codes:

  Character vector of values to treat as masked. Defaults to the
  package-wide list, configurable via the `txschools.mask_values`
  option.

## Value

`is_masked()` returns a logical vector the same length as `x`.
`mask_strip()` returns a
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `value_num` (numeric, `NA` for masked rows), `masked`
(logical), and `mask_code` (character, `NA` for non-masked rows).

## Default codes

`.`, `*`, `-`, `---`, `-1`, `-2`, `-3`, `-4`, `-99`, `n/a`, `N/A`.

## Examples

``` r
is_masked(c("12.3", "*", ".", "  -1 ", "100"))
#> [1] FALSE  TRUE  TRUE  TRUE FALSE
mask_strip(c("12.3", "*", ".", "-1", "100"))
#> # A tibble: 5 × 3
#>   value_num masked mask_code
#>       <dbl> <lgl>  <chr>    
#> 1      12.3 FALSE  NA       
#> 2      NA   TRUE   *        
#> 3      NA   TRUE   .        
#> 4      NA   TRUE   -1       
#> 5     100   FALSE  NA       
```
