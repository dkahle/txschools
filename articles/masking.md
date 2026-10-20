# Masking and suppression in TEA data

TEA masks small-cell statistics for FERPA reasons. Reported values can
include the following sentinel codes:

    #>  [1] "."   "*"   "-"   "---" "-1"  "-2"  "-3"  "-4"  "-99" "n/a" "N/A"

- `"."` — value not applicable, e.g. campus did not test that subject.
- `"*"` — value masked because the underlying student count is too
  small.
- `"-1"`, `"-2"`, `"-3"`, `"-4"`, `"-99"` — TEA-specific suppression
  flags; see the TAPR Glossary for the precise definition in any given
  year.
- `"n/a"`, `"N/A"` — explicit not-applicable string.

`txschools` reads every file with all-character columns, so these codes
**survive parsing intact**. The package never infers a value from a
masked cell.

## Helpers

\
[`is_masked`](https://dkahle.github.io/txschools/reference/is_masked.md)`(`[`c`](https://rdrr.io/r/base/c.html)`(``"12.3"``, ``"*"``, ``"."``, ``" -1 "``, ``"0"``)``)`\
`#> [1] FALSE  TRUE  TRUE  TRUE FALSE`\
[`mask_strip`](https://dkahle.github.io/txschools/reference/is_masked.md)`(`[`c`](https://rdrr.io/r/base/c.html)`(``"12.3"``, ``"*"``, ``"."``, ``"-1"``, ``"0"``)``)`\
`#> ``# A tibble: 5 × 3`\
`#>   value_num masked mask_code`\
`#>       ``<dbl>`` ``<lgl>``  ``<chr>``    `\
`#> ``1``      12.3 FALSE  ``NA``       `\
`#> ``2``      ``NA``   TRUE   *        `\
`#> ``3``      ``NA``   TRUE   .        `\
`#> ``4``      ``NA``   TRUE   -1       `\
`#> ``5``       0   FALSE  ``NA`

[`mask_strip()`](https://dkahle.github.io/txschools/reference/is_masked.md)
is the safe way to get a numeric column from a TAPR table: it returns
three parallel vectors — `value_num` (numeric, `NA` for masked rows),
`masked` (logical), and `mask_code` (the original sentinel) — so
downstream code never confuses “12.3” with “\*“.

## Formatting and unrecognized markers

Display formatting is stripped before numeric parsing — `"97%"` parses
to `97` (as printed, not divided by 100) and `"$4,668"` to `4668`:

\
[`mask_strip`](https://dkahle.github.io/txschools/reference/is_masked.md)`(`[`c`](https://rdrr.io/r/base/c.html)`(``"97%"``, ``"$4,668"``)``)`\
`#> ``# A tibble: 2 × 3`\
`#>   value_num masked mask_code`\
`#>       ``<dbl>`` ``<lgl>``  ``<chr>``    `\
`#> ``1``        97 FALSE  ``NA``       `\
`#> ``2``      ``4``668 FALSE  ``NA`

This is the package-wide convention: **numeric values are kept at the
scale TEA printed them**. The one exception is the semantic TAPR student
datasets from
[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md),
whose columns explicitly named `*_percent` are proportions (`"49.6%"`
becomes `0.496`) — the column name declares the unit.

TEA occasionally prints suppression markers beyond the sentinel list,
such as `"< 1%"`. Values that fail numeric parsing are flagged as masked
**only when they look like suppression markers** — comparison markers
(`"< 1%"`, `">99%"`) or symbol-only tokens (`"*"`, `"."`, `"?"`, `"--"`)
— with the original marker preserved in `mask_code`, never silently
degraded to an unmasked `NA`:

\
[`mask_strip`](https://dkahle.github.io/txschools/reference/is_masked.md)`(`[`c`](https://rdrr.io/r/base/c.html)`(``"< 1%"``, ``"?"``)``)`\
`#> ``# A tibble: 2 × 3`\
`#>   value_num masked mask_code`\
`#>       ``<dbl>`` ``<lgl>``  ``<chr>``    `\
`#> ``1``        ``NA`` TRUE   < 1%     `\
`#> ``2``        ``NA`` TRUE   ?`

Everything else that fails numeric parsing — year labels like
`"2019-20"`, grade spans like `"02 - 04"`, names — is ordinary text,
left unmasked with an `NA` numeric slot:

\
[`mask_strip`](https://dkahle.github.io/txschools/reference/is_masked.md)`(`[`c`](https://rdrr.io/r/base/c.html)`(``"2019-20"``, ``"02 - 04"``, ``"MCLENNAN"``)``)`\
`#> ``# A tibble: 3 × 3`\
`#>   value_num masked mask_code`\
`#>       ``<dbl>`` ``<lgl>``  ``<chr>``    `\
`#> ``1``        ``NA`` FALSE  ``NA``       `\
`#> ``2``        ``NA`` FALSE  ``NA``       `\
`#> ``3``        ``NA`` FALSE  ``NA`

The `txs_get_*()` family applies this transformation automatically when
`output = "tidy"` and exposes the masking codes used via
`attr(df, "txschools")$masking_values`.
