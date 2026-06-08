
# txschools

<!-- badges: start -->

<!-- badges: end -->

`txschools` provides reproducible, polite, on-demand access to
**public** school-performance data published by the Texas Education
Agency (TEA), including the Texas Academic Performance Reports (TAPR),
the School Report Card (SRC), and the Academic Excellence Indicator
System (AEIS) archive.

## Disclaimer

`txschools` is **not affiliated with or endorsed by the Texas Education
Agency**. It downloads files from TEA’s *public* TAPR/SRC/AEIS pages on
demand and does **not** redistribute TEA data. Users are responsible for
compliance with [TEA’s site
policies](https://tea.texas.gov/about-tea/welcome-and-overview/site-policies)
and with FERPA and other applicable privacy laws. Masking and
suppression values applied by TEA are preserved exactly; this package
**never imputes or infers masked values**.

## Installation

``` r
# install.packages("pak")
pak::pak("dkahle/txschools")
```

## Quick start

``` r
library("txschools")
```

Here is a real public TAPR/TPRS example: China Spring Elementary School
(`161920102`) for TEA report year 2025, which corresponds to the 2024-25
TAPR report. The 2025 campus report is currently exposed by TEA as an
HTML report page, so this example uses `txs_get_tapr()` to politely
request the public page and parse its student-information datasets.

The `geography` value is TEA’s organization identifier, not something
`txschools` infers from a school name. For a campus, this is the
nine-digit county-district-campus number listed in
[AskTED](https://tea.texas.gov/AskTED), TEA’s public school directory:
the first six digits identify the district and the last three identify
the campus. China Spring Elementary School is campus `102` in China
Spring ISD (`161920`), so its TAPR campus `geography` is `"161920102"`.
Keep these identifiers quoted in R so leading zeros, where present, are
preserved.

`txs_get_tapr()` returns a named list of semantic datasets. This
reflects the structure of TAPR itself: the report is not one table, but
a collection of related tables.

``` r
china_spring_elem_2025 <- txs_get_tapr(
  year = 2025,
  level = "campus",
  geography = "161920102",
  datasets = c("grade", "sex", "cohorts")
)

china_spring_elem_2025$grade
china_spring_elem_2025$sex
```

Use `txs_list_tapr_datasets()` to see the currently supported semantic
dataset keys. Use `txs_get_tapr_file()` when you need the lower-level
statewide TAPR download files in raw, wide, or tidy form.

## How it stays polite

- Conservative rate-limiting (default 1 request/sec; bulk downloads
  default to a 5-second delay between files).
- Identifies itself with a clear, package-named `User-Agent`.
- Respects `robots.txt` (configurable via
  `options("txschools.respect_robots")`).
- Never scrapes TEAL/authenticated resources.
- All downloaded files are cached under
  `tools::R_user_dir("txschools", "cache")` with a sidecar YAML
  recording the source URL, retrieval timestamp, SHA-256, and content
  type.

## Masking

TEA masks small-cell statistics for FERPA reasons. `txschools` parses
every value as character first and **never coerces masked codes to
numeric**. See `vignette("masking", package = "txschools")` for the full
list of mask codes and helper functions.
