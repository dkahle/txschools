# Texas school district boundaries (via tigris)

Downloads and simplifies the Census cartographic school-district
boundaries for Texas, returned as an `sf` in WGS84 (EPSG:4326) – the
projection web maps expect. The `geoid` column is the 7-digit NCES
LEAID; join TEA-keyed tables through
[`txs_crosswalk()`](https://dkahle.github.io/txschools/reference/txs_crosswalk.md).

## Usage

``` r
txs_boundaries(
  year = 2023,
  keep = 0.15,
  cb = TRUE,
  cache = TRUE,
  refresh = FALSE,
  verbose = TRUE
)
```

## Arguments

- year:

  Census TIGER vintage; vintages lag the calendar year, so a
  recent-but-settled year is the safe default.

- keep:

  Fraction of vertices to keep when simplifying (0-1).

- cb:

  Use cartographic-boundary (generalized) geometry.

- cache:

  If `TRUE`, reuse a cached copy when one exists.

- refresh:

  If `TRUE`, re-download even if cached.

- verbose:

  Print progress messages.

## Value

An `sf` data frame with columns `geoid`, `name`, and `geometry`, plus a
`txschools` attribute.

## Details

Requires the suggested packages sf and tigris (and uses rmapshaper for
higher-quality simplification when installed, falling back to
[`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html)).

## Examples

``` r
if (FALSE) { # \dontrun{
txs_boundaries()
} # }
```
