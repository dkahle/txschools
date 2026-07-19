# Execute a bulk-download plan

Iterates over the rows of `plan` and downloads each file that is not
already cached (or all of them if `refresh = TRUE`). Sleeps `delay`
seconds between requests for politeness regardless of the configured
per-second rate limit.

## Usage

``` r
txs_bulk_download(
  plan,
  delay = 5,
  refresh = FALSE,
  stop_on_error = FALSE,
  max_tries = 3
)
```

## Arguments

- plan:

  A tibble from
  [`txs_bulk_plan()`](https://dkahle.github.io/txschools/reference/txs_bulk_plan.md).

- delay:

  Seconds to sleep between non-cached requests.

- refresh:

  Re-download even if cached.

- stop_on_error:

  If `TRUE`, errors propagate; otherwise they are recorded in the
  `error` column and the loop continues.

- max_tries:

  Retry budget per request.

## Value

The plan with added columns `status`, `bytes`, `elapsed_s`, `sha256`,
and `error`.
