# Getting started with txschools

`txschools` makes it straightforward to pull *public* school-performance
data published by the Texas Education Agency (TEA): the Texas Academic
Performance Reports (TAPR, 2013-present), the School Report Card (SRC,
2004-2019), and the Academic Excellence Indicator System (AEIS,
2004-2012).

## Find your school

TEA identifies campuses by nine-digit county-district-campus numbers and
districts by six-digit numbers. Look them up by name:

``` r

txs_find_campus("china spring")
```

## Discover available years and downloads

``` r

txs_list_years("tapr")

downloads <- txs_list_downloads(2024, source = "tapr")
downloads
```

TAPR’s statewide data lives behind TEA’s SAS-broker “Advanced Download”
interface: one CSV per `level` × `dataset` code (`"REF"`, `"STAAR1"`,
`"GRAD"`, …). The `TAPR_*.xlsx` workbooks TEA links as “TAPR Data in
Excel” are variable dictionaries, exposed here as
`data_type = "dictionary"`.

## Download semantic TAPR datasets

``` r

tapr <- txs_get_tapr(
  year      = 2025,
  level     = "campus",
  geography = "161920102",
  datasets  = c("grade", "sex")
)
tapr$grade
```

[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md)
returns a named list because a TAPR report is a collection of datasets,
not one rectangular table.

## Download a statewide TAPR data file

``` r

df <- txs_get_tapr_file(
  year        = 2024,
  level       = "campus",
  dataset     = "REF",
  data_type   = "advanced",
  output      = "tidy"
)
df
```

Variable codes are documented in the per-year dictionary:

``` r

dict <- txs_get_tapr_dictionary(2024, "campus")
dict
```

Every call records source metadata as an attribute:

``` r

attr(df, "txschools")
```

A re-call uses the cached copy without re-downloading.

## School Report Cards

TEA publishes SRC as per-campus reports. 2004-2012 campus reports are
HTML and parse into a tidy tibble; 2013-2019 reports are PDF and are
downloaded to the cache:

``` r

src <- txs_get_src(2011, "campus", "161920102")
src
```

## AEIS

Statewide AEIS files (2004-2012) are keyed by level and dataset code:

``` r

aeis <- txs_get_aeis(2011, "district", dataset = "ref",
                     geography = "161920")
aeis
```

## Citation

``` r

txs_cite(df)
```

## Bulk multi-year downloads

``` r

plan <- txs_bulk_plan(2023:2024, levels = "campus", datasets = c("REF", "GRAD"))
plan
done <- txs_bulk_download(plan, delay = 5)
done
```
