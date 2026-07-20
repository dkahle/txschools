# Presentation helpers for the txschools district viewer (app-local, not
# package API). Ported from txschoolviewer/R/app_helpers.R; domain facts
# (homestead exemption schedule, penny math) live in the txschools
# package itself.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

# Catalog of mappable metrics. Value columns in the wide map artifact are
# paste0(key, "__", year_key).
pv_metrics <- function() {
  tibble::tibble(
    key = c("total_rate", "mo_rate", "is_rate", "mcr",
            "golden_rate", "copper_rate", "golden_pennies",
            "copper_pennies"),
    label = c(
      "Total tax rate", "M&O rate", "I&S (debt) rate",
      "Tier One compressed rate (MCR)", "Golden penny rate",
      "Copper penny rate", "Golden pennies (count)",
      "Copper pennies (count)"
    ),
    kind = c(rep("rate", 6), "count", "count"),
    palette = c("YlGnBu", "YlGnBu", "BuPu", "Greens",
                "YlOrBr", "OrRd", "YlOrBr", "OrRd")
  )
}

pv_metric_choices <- function() {
  m <- pv_metrics()
  stats::setNames(m$key, m$label)
}

pv_metric_label <- function(key) {
  m <- pv_metrics()
  m$label[match(key, m$key)] %||% key
}

pv_metric_kind <- function(key) pv_metrics()$kind[match(key, pv_metrics()$key)]

# Format a metric value for display (currency rate vs. whole pennies).
pv_format <- function(key, x) {
  kind <- pv_metric_kind(key)
  if (length(x) == 0) return(character(0))
  if (isTRUE(kind == "count")) {
    ifelse(is.na(x), "—", formatC(x, format = "d"))
  } else {
    ifelse(is.na(x), "—",
           paste0("$", formatC(x, format = "f", digits = 4)))
  }
}

# Build numeric color stops for a MapLibre interpolate() fill expression.
# `probs` sets the domain robustly (e.g. c(0.01, 0.99)) so a scale held
# constant across many years is not washed out by one outlier year.
make_color_stops <- function(values, n = 6, palette = "viridis",
                             probs = NULL) {
  values <- values[is.finite(values)]
  colors <- grDevices::hcl.colors(n, palette)
  if (!length(values)) {
    return(list(breaks = seq(0, 1, length.out = n), colors = colors))
  }
  rng <- if (is.null(probs)) range(values) else
    stats::quantile(values, probs = probs, names = FALSE)
  if (diff(rng) <= .Machine$double.eps) {
    rng <- rng + c(-0.5, 0.5)  # nudge degenerate range
  }
  list(breaks = seq(rng[1], rng[2], length.out = n), colors = colors)
}

# Homestead exemption by school-year LABEL ("2023-24"); the schedule
# itself lives in the package, keyed by ending year.
homestead_exemption <- function(school_year) {
  end_year <- as.integer(substr(school_year, 1, 4)) + 1L
  txschools::txs_homestead_exemption(end_year)
}

# Annual school taxes ($) on a home after the non-senior homestead
# exemption. `value` is a rate ($/$100) unless kind == "count" (penny
# counts, rate-equivalent value/100).
taxes_on_home <- function(value, kind, school_year, home_value) {
  taxable <- pmax(home_value - homestead_exemption(school_year), 0)
  rate_equiv <- if (identical(kind, "count")) value / 100 else value
  rate_equiv * taxable / 100
}

# School-year label embedded in a wide value column:
# "total_rate__2022_23" -> "2022-23".
col_to_sy <- function(col) gsub("_", "-", sub("^.*__", "", col))

# Curated axis presets for the Finance tab's Sankey. txs_peims_flow()'s
# `axes` argument has real validity constraints (canonical order;
# "source" must be immediately followed by "fund"), so the UI offers a
# small set of known-valid combinations rather than a free-form picker.
fin_axes_presets <- function() {
  tibble::tibble(
    key = c("source_fund_function", "fund_function_object",
            "fund_function_program"),
    label = c(
      "Revenue sources → funds → functions",
      "Funds → functions → what was bought",
      "Funds → functions → who it served"
    ),
    axes = list(
      c("source", "fund", "function"),
      c("fund", "function", "object"),
      c("fund", "function", "program")
    )
  )
}

fin_axes_choices <- function() {
  p <- fin_axes_presets()
  stats::setNames(p$key, p$label)
}

fin_axes_for <- function(key) {
  p <- fin_axes_presets()
  p$axes[[match(key, p$key)]]
}
