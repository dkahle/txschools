# Normalize a TEA "school year" argument

The package uses the *ending* calendar year to identify a TEA school
year, matching TEA report URLs and `ccyy` parameters. For example,
`2025` means the 2024-25 school year. This helper validates the input
and returns an integer.

## Usage

``` r
normalize_year(year, source = NULL)
```

## Arguments

- year:

  Integer scalar; the ending calendar year.

- source:

  Optional TEA program (`"tapr"`, `"aeis"`, `"src"`, `"peims"`,
  `"taxrates"`, `"first"`); when given, the year is validated against
  that program's coverage.

## Value

Integer scalar.
