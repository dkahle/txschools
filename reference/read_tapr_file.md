# Read a TAPR/SRC/AEIS file as all-character columns

Reads with everything as character so masking codes like `"*"`, `"."`,
`"-1"` survive the parse intact. Numeric coercion happens only in
`to_tidy()` and
[`mask_strip()`](https://dkahle.github.io/txschools/reference/is_masked.md).

## Usage

``` r
read_tapr_file(path, file_format = NULL)
```

## Details

For `.zip` files (TEA frequently distributes a zipped bundle), the
archive is extracted alongside the zip and the contained data file is
parsed.
