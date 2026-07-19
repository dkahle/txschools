#' Build money-flow (Sankey) data from PEIMS finance rows
#'
#' Aggregates a [txs_get_peims_finance()] result (typically filtered to
#' one district) into the stage-to-stage edge list behind an
#' income-statement-style flow diagram: where the money came from, which
#' fund it moved through, and what it was spent on. Plot the result with
#' [txs_plot_peims_flow()] or any Sankey tool.
#'
#' @section Axes and honesty:
#' Available axes, in canonical order:
#' * `"source"` -- revenue class from the object code: local (5700s),
#'   state (5800s), federal (5900s).
#' * `"fund"` -- TEA fund (general fund, food service, Title I, ...).
#' * `"function"` -- what the spending was for (instruction, ...).
#' * `"object"` -- what was bought: payroll (6100s), contracted
#'   services (6200s), supplies (6300s), other operating (6400s), debt
#'   service (6500s), capital outlay (6600s).
#' * `"program"` -- program intent (basic, special education, ...).
#'
#' Every edge is a genuine total from the data: revenue rows record
#' (source, fund) jointly, and expenditure rows record (fund, function,
#' object, program) jointly. Because TEA does not record which revenue
#' dollar paid which bill, `"source"` may only be followed by `"fund"`
#' (money is only traceable source-to-spending *through* a fund);
#' requesting e.g. `c("source", "function")` errors.
#'
#' @section Fund balances:
#' Funds rarely break even within a year. When `axes` starts at
#' `"source"`, each fund's shortfall is fed by a **"From fund balance"**
#' node on the source axis and each fund's surplus drains to a
#' **"To fund balance"** node on the following axis, so both sides of
#' every fund reconcile exactly.
#'
#' @param x A tibble from [txs_get_peims_finance()] (tidy output),
#'   usually filtered to one district and year.
#' @param axes Character vector of two or more axes from the list
#'   above, in canonical order.
#' @param lump Maximum number of nodes per axis before smaller ones
#'   fold into an "Other ..." node (balance nodes excepted).
#' @return A tibble of class `peims_flow` with columns `from_axis`,
#'   `from`, `to_axis`, `to`, `amount`, carrying the axis vector as an
#'   attribute.
#' @examples
#' \dontrun{
#' txs_get_peims_finance(2024, "actual", "district") |>
#'   dplyr::filter(district == "161920") |>
#'   txs_peims_flow() |>
#'   txs_plot_peims_flow()
#' }
#' @export
txs_peims_flow <- function(x,
                           axes = c("source", "fund", "function"),
                           lump = 5) {
  all_axes <- c("source", "fund", "function", "object", "program")
  axes <- as.character(axes)
  if (length(axes) < 2L || !all(axes %in% all_axes)) {
    stop("`axes` must be two or more of: ",
         paste(sprintf('"%s"', all_axes), collapse = ", "), call. = FALSE)
  }
  if (is.unsorted(match(axes, all_axes))) {
    stop("`axes` must respect the canonical order: ",
         paste(all_axes, collapse = " -> "), call. = FALSE)
  }
  if ("source" %in% axes && !identical(axes[1:2], c("source", "fund"))) {
    stop(
      "\"source\" can only be followed by \"fund\": TEA records which ",
      "fund each revenue dollar entered, but not which bill it paid, ",
      "so source-to-spending flows are only honest through a fund.",
      call. = FALSE
    )
  }
  if (!all(c("object_code", "fund_code", "function_code", "amount") %in%
             names(x))) {
    stop("`x` must be the tidy output of `txs_get_peims_finance()`.",
         call. = FALSE)
  }

  rev_rows <- x[grepl("^5", x$object_code), , drop = FALSE]
  exp_rows <- x[grepl("^6", x$object_code), , drop = FALSE]

  # Node values per axis, on the rows where the axis is defined.
  axis_values <- function(rows, axis) {
    switch(
      axis,
      source = peims_source_class(rows$object_code),
      fund = peims_axis_label(rows, "fund", "Fund"),
      `function` = peims_axis_label(rows, "function", "Function"),
      object = peims_object_class(rows$object_code),
      program = peims_axis_label(rows, "program_intent", "Program")
    )
  }

  # Lump each axis to its top nodes by expenditure (funds are lumped on
  # spending so both sides of a fund fold identically).
  lump_map <- list()
  for (ax in axes) {
    if (ax == "source") next
    vals <- axis_values(exp_rows, ax)
    totals <- tapply(exp_rows$amount, vals, sum)
    keep <- names(sort(totals, decreasing = TRUE))
    keep <- utils::head(keep, lump)
    other <- sprintf("Other %ss", if (ax == "program") "program" else ax)
    lump_map[[ax]] <- function(v, keep., other.) {
      ifelse(v %in% keep., v, other.)
    }
    attr(lump_map[[ax]], "keep") <- keep
    attr(lump_map[[ax]], "other") <- other
  }
  apply_lump <- function(v, ax) {
    if (ax == "source") return(v)
    f <- lump_map[[ax]]
    f(v, attr(f, "keep"), attr(f, "other"))
  }

  edge <- function(rows, ax_from, ax_to) {
    from <- apply_lump(axis_values(rows, ax_from), ax_from)
    to <- apply_lump(axis_values(rows, ax_to), ax_to)
    agg <- stats::aggregate(rows$amount, list(from = from, to = to), sum)
    tibble::tibble(
      from_axis = ax_from, from = agg$from,
      to_axis = ax_to, to = agg$to, amount = agg$x
    )
  }

  edges <- list()
  for (i in seq_len(length(axes) - 1L)) {
    pair <- axes[c(i, i + 1L)]
    rows <- if (identical(pair, c("source", "fund"))) rev_rows else exp_rows
    edges[[i]] <- edge(rows, pair[1], pair[2])
  }
  edges <- dplyr::bind_rows(edges)

  # Per-fund balancing between the revenue and spending sides.
  if (identical(axes[1:2], c("source", "fund"))) {
    rev_by_fund <- tapply(rev_rows$amount,
                          apply_lump(axis_values(rev_rows, "fund"), "fund"),
                          sum)
    exp_by_fund <- tapply(exp_rows$amount,
                          apply_lump(axis_values(exp_rows, "fund"), "fund"),
                          sum)
    funds <- union(names(rev_by_fund), names(exp_by_fund))
    get0n <- function(v, nm) if (nm %in% names(v)) v[[nm]] else 0
    for (f in funds) {
      net <- get0n(exp_by_fund, f) - get0n(rev_by_fund, f)
      if (net > 0) {
        edges <- dplyr::bind_rows(edges, tibble::tibble(
          from_axis = "source", from = "From fund balance",
          to_axis = "fund", to = f, amount = net
        ))
      } else if (net < 0) {
        edges <- dplyr::bind_rows(edges, tibble::tibble(
          from_axis = "fund", from = f,
          to_axis = if (length(axes) >= 3L) axes[3] else "balance",
          to = "To fund balance",
          amount = -net
        ))
      }
    }
  }

  edges <- edges[edges$amount > 0, , drop = FALSE]
  edges <- edges[order(match(edges$from_axis, axes), -edges$amount), ]
  attr(edges, "axes") <- axes
  class(edges) <- c("peims_flow", class(edges))
  edges
}

# Revenue class from a 5xxx object code.
peims_source_class <- function(object_code) {
  dplyr::case_when(
    grepl("^57", object_code) ~ "Local revenue",
    grepl("^58", object_code) ~ "State revenue",
    grepl("^59", object_code) ~ "Federal revenue",
    .default = "Other revenue"
  )
}

# Spending class from a 6xxx object code.
peims_object_class <- function(object_code) {
  dplyr::case_when(
    grepl("^61", object_code) ~ "Payroll",
    grepl("^62", object_code) ~ "Contracted services",
    grepl("^63", object_code) ~ "Supplies & materials",
    grepl("^64", object_code) ~ "Other operating",
    grepl("^65", object_code) ~ "Debt service",
    grepl("^66", object_code) ~ "Capital outlay",
    .default = "Other objects"
  )
}

# Human label for an axis, falling back to the code when the label
# columns are absent (labels = FALSE pulls).
peims_axis_label <- function(rows, prefix, noun) {
  lab_col <- paste0(prefix, "_label")
  code_col <- paste0(prefix, "_code")
  if (lab_col %in% names(rows) && !all(is.na(rows[[lab_col]]))) {
    lab <- stringr::str_to_sentence(rows[[lab_col]])
    ifelse(is.na(lab) | !nzchar(lab),
           paste(noun, rows[[code_col]]), lab)
  } else {
    paste(noun, rows[[code_col]])
  }
}

#' Plot a PEIMS money-flow diagram
#'
#' Renders the edge list from [txs_peims_flow()] as a Sankey diagram in
#' the style of an income-statement flow chart, using the ggsankey
#' package (not on CRAN; install with
#' `remotes::install_github("davidsjoberg/ggsankey")`). Returns a
#' ggplot, so titles, themes, and `ggsave()` all work as usual.
#'
#' @param flows A `peims_flow` tibble from [txs_peims_flow()].
#' @param palette Optional named character vector of node colors,
#'   overriding the defaults (first- and last-axis nodes get color;
#'   middle-axis and balance nodes are neutral).
#' @param unit Dollars per ribbon strand; flows are drawn in units of
#'   `unit` (ggsankey sizes flows by row count). The default `1e4`
#'   keeps rendering exact to the nearest $10,000.
#' @param space Vertical gap between nodes, in `unit`s. Default scales
#'   with the total flow.
#' @param label_wrap Width at which node labels wrap.
#' @return A ggplot object.
#' @importFrom dplyr .data
#' @export
txs_plot_peims_flow <- function(flows,
                                palette = NULL,
                                unit = 1e4,
                                space = NULL,
                                label_wrap = 16) {
  if (!inherits(flows, "peims_flow")) {
    stop("`flows` must come from `txs_peims_flow()`.", call. = FALSE)
  }
  for (pkg in c("ggplot2", "ggsankey")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Package `", pkg, "` is required for flow plots.",
        if (pkg == "ggsankey") {
          '\nInstall it with remotes::install_github("davidsjoberg/ggsankey").'
        },
        call. = FALSE
      )
    }
  }
  axes <- attr(flows, "axes")

  # Node totals: outflow where a node has one, else inflow.
  outflow <- stats::aggregate(
    flows$amount, list(axis = flows$from_axis, node = flows$from), sum
  )
  inflow <- stats::aggregate(
    flows$amount, list(axis = flows$to_axis, node = flows$to), sum
  )
  nodes <- rbind(outflow, inflow[!paste(inflow$axis, inflow$node) %in%
                                   paste(outflow$axis, outflow$node), ])
  node_amt <- stats::setNames(nodes$x, paste(nodes$axis, nodes$node))

  # Lodes rows: one uncounted row per unit, per edge, at the from-axis;
  # plus terminal rows so inflow-only nodes are drawn and labeled.
  n_of <- function(amount) pmax(1L, as.integer(round(amount / unit)))
  seg <- flows[rep(seq_len(nrow(flows)), n_of(flows$amount)), , drop = FALSE]
  lodes <- tibble::tibble(
    x = seg$from_axis, node = seg$from,
    next_x = seg$to_axis, next_node = seg$to
  )
  terminal <- unique(paste(flows$to_axis, flows$to))
  terminal <- terminal[!terminal %in% paste(flows$from_axis, flows$from)]
  if (length(terminal)) {
    t_axis <- sub(" .*$", "", terminal)
    t_node <- sub("^[^ ]+ ", "", terminal)
    t_n <- n_of(node_amt[terminal])
    lodes <- dplyr::bind_rows(lodes, tibble::tibble(
      x = rep(t_axis, t_n), node = rep(t_node, t_n),
      next_x = NA_character_, next_node = NA_character_
    ))
  }

  axis_lv <- unique(c(axes, flows$to_axis))
  balance_nodes <- c("From fund balance", "To fund balance")
  node_order <- function(ax) {
    nm <- nodes[nodes$axis == ax, , drop = FALSE]
    nm <- nm[order(nm$x), , drop = FALSE]  # smallest first = bottom
    v <- nm$node
    c(v[v %in% balance_nodes | grepl("^Other ", v)],
      v[!(v %in% balance_nodes | grepl("^Other ", v))])
  }
  node_lv <- unique(unlist(lapply(axis_lv, node_order)))

  lodes$x <- factor(lodes$x, axis_lv)
  lodes$next_x <- factor(lodes$next_x, axis_lv)
  lodes$node <- factor(lodes$node, node_lv)
  lodes$next_node <- factor(lodes$next_node, node_lv)

  pal <- peims_flow_palette(nodes, axis_lv, balance_nodes)
  if (!is.null(palette)) pal[names(palette)] <- palette

  labs_map <- stats::setNames(
    paste0(
      stringr::str_wrap(nodes$node, label_wrap), "\n",
      peims_dollar_label(nodes$x)
    ),
    nodes$node
  )

  total <- sum(flows$amount[flows$from_axis == axes[1]])
  space <- space %||% (0.09 * total / unit)

  ggplot2::ggplot(
    lodes,
    ggplot2::aes(
      x = .data$x, next_x = .data$next_x,
      node = .data$node, next_node = .data$next_node,
      fill = .data$node,
      label = labs_map[as.character(.data$node)]
    )
  ) +
    ggsankey::geom_sankey(flow.alpha = 0.55, node.color = NA,
                          width = 0.04, space = space) +
    ggsankey::geom_sankey_text(size = 3, color = "grey15",
                               lineheight = 0.95, space = space) +
    ggplot2::scale_fill_manual(values = pal, guide = "none", na.value = "grey80") +
    ggplot2::scale_x_discrete(expand = c(0.12, 0.02)) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_void(base_size = 12)
}

# Default node colors: categorical hues on the outer axes, neutral
# grays for middle-axis and balance/other nodes.
peims_flow_palette <- function(nodes, axis_lv, balance_nodes) {
  hues <- c("#2a78d6", "#008300", "#e87ba4", "#eda100",
            "#1baf7a", "#eb6834", "#4a3aa7", "#e34948")
  outer_axes <- axis_lv[c(1, length(axis_lv))]
  pal <- character(0)
  for (ax in axis_lv) {
    nm <- nodes[nodes$axis == ax, , drop = FALSE]
    nm <- nm[order(-nm$x), , drop = FALSE]
    plain <- nm$node[!(nm$node %in% balance_nodes | grepl("^Other ", nm$node))]
    if (ax %in% outer_axes) {
      k <- min(length(plain), length(hues))
      pal[plain[seq_len(k)]] <- hues[seq_len(k)]
      if (length(plain) > k) pal[plain[-seq_len(k)]] <- "grey72"
    } else {
      pal[plain] <- "grey55"
    }
    pal[nm$node[grepl("^Other ", nm$node)]] <- "grey72"
  }
  pal[balance_nodes] <- "grey60"
  pal
}

# "$4.9M"-style labels without a scales dependency.
peims_dollar_label <- function(x) {
  ifelse(
    abs(x) >= 995e6, sprintf("$%.1fB", x / 1e9),
    ifelse(abs(x) >= 995e3, sprintf("$%.1fM", x / 1e6),
           sprintf("$%.0fK", x / 1e3))
  )
}
