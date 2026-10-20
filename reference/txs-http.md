# Internal HTTP helpers

Thin wrappers around `httr2` that enforce:

- a clear, package-identifying User-Agent,

- per-host throttling (configurable via
  `options("txschools.rate_per_sec")`),

- retries with exponential back-off on transient errors,

- configurable timeout (`options("txschools.timeout")`),

- a `robots.txt` check before each request.

The method is left implicit (curl's POST-with-body), never set with
[`httr2::req_method()`](https://httr2.r-lib.org/reference/req_method.html):
a 302 answer to the post must be followed as a GET, which an explicit
method would carry over to the redirect.

`method = "post"` sends `params` as a URL-encoded form body (used for
TEA's SAS broker and AEIS CGI endpoints); `method = "get"` appends
`params` to the query string. `params` may also be a single pre-encoded
query string like `"sumlev=C&setpick=REF"`.

## Usage

``` r
http_request(url, timeout = NULL, max_tries = NULL, cookies = NULL)

http_get(url, timeout = NULL, max_tries = NULL, cookies = NULL)

http_post_form(url, params, timeout = NULL, max_tries = NULL, cookies = NULL)

http_download(
  url,
  dest,
  timeout = NULL,
  max_tries = NULL,
  method = c("get", "post"),
  params = NULL
)
```
