# Check robots.txt for a URL

Caches the result per host for the current R session in
`.txs_robots_cache` (created in `.onLoad`).

## Usage

``` r
check_robots(url)
```

## Arguments

- url:

  Target URL.

## Value

`TRUE` if the path is permitted (or robots.txt is missing), `FALSE`
otherwise. If `options("txschools.respect_robots")` is `TRUE` and the
path is disallowed, the caller is expected to refuse the request.
