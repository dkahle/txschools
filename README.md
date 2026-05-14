
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
compliance with [TEA’s terms of
use](https://tea.texas.gov/about-tea/welcome-and-overview/terms-of-use-and-linking-policy)
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

# What years are available?
txs_list_years("tapr")

# What downloads exist for a given year?
txs_list_downloads(2023, source = "tapr")

# Download (or use cached copy of) the campus-level advanced TAPR file
df <- txs_get_tapr(
  year       = 2023,
  level      = "campus",
  data_type  = "advanced",
  file_format = "csv",
  output     = "tidy"
)

# Where the file lives + its source metadata
attr(df, "txschools")
```

## How it stays polite

- Conservative rate-limiting (default 10 requests/sec; bulk downloads
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
