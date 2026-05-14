
# txschools

<!-- badges: start -->

<!-- badges: end -->

`txschools` provides reproducible, polite, on-demand access to
**public** school-performance data published by the Texas Education
Agency (TEA), including the Texas Academic Performance Reports (TAPR),
the School Report Card (SRC), and the AEIS archive.

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
library(txschools)
```

Here is a real public TAPR/TPRS example: China Spring Elementary School
(`161920102`) for TEA report year 2025, which corresponds to the 2024-25
TAPR report. The 2025 campus report is currently exposed by TEA as an
HTML report page, so this example uses `txs_get_tapr()` to politely
request the public page and parse the student-information table.

``` r
china_spring <- txs_get_tapr(
  year = 2025,
  level = "campus",
  geography = "161920102",
  data_type = "rates",
  file_format = "html",
  output = "raw",
  verbose = FALSE
)

rows <- match(
  c(
    "Total Students", "Grade 2", "Grade 3", "Grade 4",
    "Economically Disadvantaged", "EB Students/EL",
    "At-Risk", "Special Education"
  ),
  china_spring$measure,
  nomatch = 0L
)

china_spring_summary <- china_spring[rows, ]
knitr::kable(china_spring_summary)
```

| measure                    | campus_count | campus_percent | district | state     |
|:---------------------------|:-------------|:---------------|:---------|:----------|
| Total Students             | 613          | 100.0%         | 3,011    | 5,530,499 |
| Grade 2                    | 181          | 29.5%          | 6.0%     | 7.0%      |
| Grade 3                    | 203          | 33.1%          | 6.7%     | 7.3%      |
| Grade 4                    | 229          | 37.4%          | 7.6%     | 7.3%      |
| Economically Disadvantaged | 229          | 37.4%          | 33.8%    | 60.5%     |
| EB Students/EL             | 22           | 3.6%           | 3.6%     | 24.3%     |
| At-Risk                    | 146          | 23.8%          | 19.7%    | 53.5%     |
| Special Education          | 103          | 16.8%          | 13.0%    | 15.3%     |

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
