# txschools district viewer — slippy-map explorer of Texas school
# district tax rates. Launch with txschools::txs_viewer(); data comes
# from the artifacts baked by txschools::txs_viewer_prepare().

library(shiny)
library(bslib)
library(mapgl)
library(sf)
library(dplyr)
library(plotly)
library(shinyWidgets)

# --- shared helpers (pv_metrics, make_color_stops, pv_format, ...) -----------
source(file.path(getwd(), "helpers.R"), local = TRUE)

# --- data ---------------------------------------------------------------------
data_dir <- getOption(
  "txschools.viewer_data_dir",
  file.path(txschools::txs_cache_dir(), "viewer")
)
districts  <- readRDS(file.path(data_dir, "districts.rds"))
finance    <- readRDS(file.path(data_dir, "finance.rds"))
meta       <- jsonlite::read_json(file.path(data_dir, "meta.json"), simplifyVector = TRUE)

# The Finance tab's PEIMS summary is optional -- baked separately via
# txs_viewer_prepare_finance() since it is much slower to prepare than
# the tax-rate data above. Absent, the tab shows a message instead of
# erroring the whole app.
peims_summary_path <- file.path(data_dir, "peims_summary.rds")
has_finance <- file.exists(peims_summary_path)
peims_summary <- if (has_finance) readRDS(peims_summary_path) else NULL
if (has_finance) {
  # Composite key sidesteps needing a separate district-vs-charter
  # lookup: PEIMS itself is the only place that distinction exists.
  fin_entities <- unique(peims_summary[c("district", "district_name", "type")])
  fin_entities <- fin_entities[order(fin_entities$district_name), ]
  fin_entity_choices <- stats::setNames(
    paste(fin_entities$district, fin_entities$type, sep = "::"),
    sprintf("%s (%s)", fin_entities$district_name,
           tools::toTitleCase(fin_entities$type))
  )
  fin_years <- sort(unique(peims_summary$school_year))
  fin_bases <- sort(unique(peims_summary$basis))
}

avail_years <- sort(unique(finance$school_year))
# Precompute centroids (lng/lat) for fly-to on district search.
ctr <- suppressWarnings(sf::st_coordinates(sf::st_centroid(sf::st_geometry(districts))))
centroids <- stats::setNames(asplit(ctr, 1), districts$geoid)
district_choices <- stats::setNames(
  districts$geoid, districts$district_name
)[order(districts$district_name)]
# Clean (boundary) name per geoid, for consistent labels in the compare chart.
district_name_by_geoid <- stats::setNames(districts$district_name, districts$geoid)

# Build a MapLibre data-driven fill expression for one value column.
fill_expr <- function(col, stops) {
  interpolate(
    column = col,
    values = stops$breaks,
    stops  = stops$colors,
    na_color = "#d9d9d9"
  )
}

# Reactive-free helpers ---------------------------------------------------------
col_for <- function(metric, year) paste0(metric, "__", gsub("-", "_", year))

# All baked values of a metric across EVERY year column. Used to build a color
# scale that stays constant as the animation steps through time.
metric_values_all <- function(metric) {
  cols <- grep(paste0("^", metric, "__"), names(districts), value = TRUE)
  unlist(lapply(cols, function(cc) districts[[cc]]), use.names = FALSE)
}

# Tax-dollar values of a metric across EVERY year column for a given home value
# (after each year's homestead exemption). Backs the constant-scale dollar legend.
metric_dollars_all <- function(metric, home_value) {
  kind <- pv_metric_kind(metric)
  cols <- grep(paste0("^", metric, "__"), names(districts), value = TRUE)
  vals <- lapply(cols, function(cc)
    taxes_on_home(districts[[cc]], kind, col_to_sy(cc), home_value))
  unlist(vals, use.names = FALSE)
}

# --- Finance tab: PEIMS money-flow (Sankey) diagrams --------------------------
# Built once at app-source time (has_finance is a load-time fact, not
# reactive state), so no need for a placeholder + uiOutput swap.
finance_tab <- if (has_finance) {
  # c("Display label" = "value"), shiny's convention (see e.g. map_yaxis
  # below) -- filtered to whichever bases were actually prepared.
  basis_all <- c("Actual" = "actual", "Budget" = "budget")
  basis_choices <- basis_all[basis_all %in% fin_bases]
  nav_panel(
    "Finance",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectizeInput("fin_entity", "Find a district or charter",
                       choices = c("Type to search..." = "", fin_entity_choices),
                       selected = ""),
        sliderTextInput("fin_year", "School year",
                        choices = fin_years, selected = max(fin_years),
                        grid = TRUE),
        radioButtons("fin_basis", "Basis", choices = basis_choices,
                     selected = basis_choices[[1]]),
        selectInput("fin_axes", "Show", choices = fin_axes_choices()),
        sliderInput("fin_lump", "Categories before folding into \"Other\"",
                    min = 3, max = 8, value = 5, step = 1),
        hr(),
        div(class = "small text-muted",
            "Ribbons only connect stages TEA's accounting actually ",
            "records — revenue sources trace to spending through ",
            "funds, the one join the data supports; funds are ",
            "reconciled against fund balance, transfers, and other ",
            "financing.")
      ),
      card(
        full_screen = TRUE,
        card_header(textOutput("fin_title", inline = TRUE)),
        plotOutput("fin_plot", height = "70vh")
      )
    )
  )
} else {
  nav_panel(
    "Finance",
    div(
      class = "text-muted", style = "padding: 2rem;",
      p("Run ", tags$code("txschools::txs_viewer_prepare_finance()"),
        " to enable this tab (downloads and aggregates several PEIMS ",
        "financial files; first run takes roughly 10-20 minutes).")
    )
  )
}

# --- UI -----------------------------------------------------------------------
ui <- page_navbar(
  title = "Texas School District Tax Rates",
  theme = bs_theme(version = 5, bootswatch = "flatly"),

  # Tab 1: the animated choropleth map explorer.
  nav_panel(
    "Map",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        sliderTextInput("year", "School year",
                        choices = avail_years, selected = max(avail_years),
                        grid = TRUE,
                        animate = animationOptions(interval = 1100, loop = TRUE)),
        selectInput("metric", "Color districts by",
                    choices = pv_metric_choices(), selected = "total_rate"),
        selectizeInput("search", "Find a district",
                       choices = c("Type to search..." = "", district_choices),
                       selected = ""),
        radioButtons("map_yaxis", "Legend shows",
                     choices = c("Tax rate ($ per $100 value)" = "rate",
                                 "Taxes by home value" = "dollars"),
                     selected = "rate"),
        conditionalPanel(
          condition = "input.map_yaxis == 'dollars'",
          numericInput("map_home_value", "Home value ($)",
                       value = 350000, min = 0, step = 10000)
        ),
        hr(),
        div(class = "small text-muted",
            strong("Legend"),
            uiOutput("legend")),
        hr(),
        div(class = "small text-muted",
            "Golden pennies: first 8¢ of M&O effort above the compressed rate ",
            "(MCR). Copper pennies: effort above that, subject to recapture. ",
            "Rates are $ per $100 of taxable value; dollar amounts apply the ",
            "standard non-senior homestead exemption.")
      ),
      layout_columns(
        col_widths = c(12),
        card(
          full_screen = TRUE,
          card_header(textOutput("map_title", inline = TRUE)),
          maplibreOutput("map", height = "70vh")
        ),
        card(
          card_header("District detail"),
          uiOutput("detail")
        )
      )
    )
  ),

  # Tab 2: compare a metric across several districts over time.
  nav_panel(
    "Compare districts",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectizeInput("cmp_districts", "Districts to compare",
                       choices = NULL, multiple = TRUE,
                       options = list(placeholder = "Type to add districts…")),
        selectInput("cmp_metric", "Metric",
                    choices = pv_metric_choices(), selected = "total_rate"),
        radioButtons("cmp_yaxis", "Y axis",
                     choices = c("Tax rate ($ per $100 value)" = "rate",
                                 "Taxes by home value" = "dollars"),
                     selected = "rate"),
        conditionalPanel(
          condition = "input.cmp_yaxis == 'dollars'",
          numericInput("cmp_home_value", "Home value ($)",
                       value = 350000, min = 0, step = 10000)
        ),
        hr(),
        div(class = "small text-muted",
            "Pick any number of districts to chart a metric over time. ",
            "Click a line (or use the highlight box above the chart) to focus ",
            "one district; double-click to reset. ",
            "Dollar amounts apply the standard non-senior homestead exemption ",
            "for each year. MCR and golden/copper pennies apply to 2019-20 onward.")
      ),
      card(
        full_screen = TRUE,
        card_header(textOutput("cmp_title", inline = TRUE)),
        plotlyOutput("compare_plot", height = "74vh")
      )
    )
  ),

  # Tab 3: PEIMS money-flow diagram for one district/charter, optional.
  finance_tab
)

# --- Server -------------------------------------------------------------------
server <- function(input, output, session) {

  # Server-side selectize for the large (~1,000) district list (Compare tab).
  updateSelectizeInput(session, "cmp_districts",
                       choices = district_choices, server = TRUE)

  cur_col <- reactive({
    req(input$metric, input$year)
    cc <- col_for(input$metric, input$year)
    validate(need(cc %in% names(districts), "No data for this metric/year."))
    cc
  })

  # Home value for the "Taxes by home value" legend mode (default $350k).
  map_home <- reactive({
    hv <- input$map_home_value
    if (is.null(hv) || is.na(hv)) 350000 else hv
  })
  map_dollars <- reactive(identical(input$map_yaxis, "dollars"))

  # Color scale held CONSTANT across years, so the play animation shows real
  # change, not a moving scale. In rate mode `breaks` are rate values; in dollars
  # mode they are tax dollars on `map_home()` (after the homestead exemption),
  # constant across years. A 1-99% domain keeps a lone outlier year from washing
  # out the range.
  map_scale <- reactive({
    req(input$metric)
    pal  <- pv_metrics()$palette[match(input$metric, pv_metrics()$key)]
    vals <- if (map_dollars()) metric_dollars_all(input$metric, map_home())
            else metric_values_all(input$metric)
    st <- make_color_stops(vals, n = 6, palette = pal, probs = c(0.01, 0.99))
    c(st, list(dollars = map_dollars()))
  })

  # Fill paint for the displayed year: an interpolate() expression, or a flat
  # color when a sub-exemption home value makes every bill $0.
  map_fill <- reactive({
    col <- cur_col()
    sc  <- map_scale()
    if (!isTRUE(sc$dollars)) return(fill_expr(col, sc))
    # Convert the constant DOLLAR breaks into this year's raw-column breaks:
    # dollars = (raw * c) * taxable / 100  =>  raw = dollars * 100 / (c * taxable).
    cc      <- if (identical(pv_metric_kind(input$metric), "count")) 0.01 else 1
    taxable <- max(map_home() - homestead_exemption(input$year), 0)
    if (taxable <= 0) return(sc$colors[1])
    fill_expr(col, list(breaks = sc$breaks * 100 / (cc * taxable),
                        colors = sc$colors))
  })

  output$map_title <- renderText({
    base <- paste0(pv_metric_label(input$metric), " — ", input$year)
    if (map_dollars())
      paste0(base, " · taxes on a $",
             formatC(map_home(), format = "d", big.mark = ","), " home")
    else base
  })

  # Initial render only; later changes go through the proxy (no re-render).
  output$map <- renderMaplibre({
    maplibre(
      style  = carto_style("positron"),
      bounds = as.numeric(sf::st_bbox(districts))
    ) |>
      add_fill_layer(
        id           = "districts",
        source       = districts,
        fill_color   = isolate(map_fill()),
        fill_opacity = 0.75,
        fill_outline_color = "#ffffff",
        tooltip      = "district_name"
      )
  })

  # Recolor on metric / year / legend-mode / home-value change via the proxy
  # (the play button drives the year frame by frame).
  observeEvent(
    list(input$metric, input$year, input$map_yaxis, input$map_home_value), {
      maplibre_proxy("map") |>
        set_paint_property("districts", "fill-color", map_fill())
    }, ignoreInit = TRUE)

  # Custom HTML legend (fully reactive, independent of the map canvas). Labels
  # are rate values or tax dollars depending on the legend-mode toggle.
  output$legend <- renderUI({
    sc  <- map_scale()
    fmt <- if (isTRUE(sc$dollars))
      function(x) paste0("$", formatC(round(x), format = "d", big.mark = ","))
    else function(x) pv_format(input$metric, x)
    swatch <- function(color, val) {
      tags$div(style = "display:flex;align-items:center;gap:6px;",
               tags$span(style = sprintf(
                 "width:14px;height:14px;background:%s;display:inline-block;border:1px solid #999;",
                 color)),
               tags$span(fmt(val)))
    }
    Map(swatch, sc$colors, sc$breaks) |> tagList()
  })

  # --- selection (map click or search) ---------------------------------------
  selected <- reactiveVal(NULL)

  # NOTE: confirm the exact mapgl click input name during verification; mapgl
  # exposes clicked features as input$<id>_feature_click with $properties.
  observeEvent(input$map_feature_click, {
    props <- input$map_feature_click$properties
    if (!is.null(props$geoid)) selected(props$geoid)
  })

  observeEvent(input$search, {
    if (!nzchar(input$search)) return()
    selected(input$search)
    cc <- centroids[[input$search]]
    if (!is.null(cc)) {
      maplibre_proxy("map") |> fly_to(center = as.numeric(cc), zoom = 9)
    }
  }, ignoreInit = TRUE)

  output$detail <- renderUI({
    g <- selected()
    if (is.null(g)) {
      return(div(class = "text-muted",
                 "Click a district on the map (or search) to see its rate breakdown."))
    }
    d <- finance |> filter(.data$geoid == g) |> arrange(.data$school_year)
    if (nrow(d) == 0) return(div(class = "text-muted", "No finance data for this district."))
    nm <- d$district_name[[1]] %||% districts$district_name[match(g, districts$geoid)]
    cdn <- d$district[[1]] %||% NA

    tagList(
      h5(sprintf("%s (CDN %s)", nm, cdn)),
      plotlyOutput("trend", height = "300px")
    )
  })

  # Trend: total / M&O / I&S across years.
  output$trend <- renderPlotly({
    g <- selected(); req(g)
    d <- finance |> filter(.data$geoid == g) |> arrange(.data$school_year)
    # Abbreviated year labels: "05-06" instead of "2005-06".
    d$yr <- substr(d$school_year, 3, 7)
    plot_ly(d, x = ~yr) |>
      add_lines(y = ~total_rate, name = "Total") |>
      add_lines(y = ~mo_rate, name = "M&O") |>
      add_lines(y = ~is_rate, name = "I&S") |>
      layout(
        title = "Rate history",
        # Dollars on the y-axis, gridlines every $0.20.
        yaxis = list(title = "$/$100", tickprefix = "$", tickformat = ".2f",
                     tick0 = 0, dtick = 0.2),
        # Force a categorical axis so plotly does not parse "2005-06" as a
        # year-month date (which silently drops years from 2012-13 on, where
        # the "month" exceeds 12). Horizontal labels via tickangle = 0.
        xaxis = list(title = "", type = "category",
                     categoryorder = "array", categoryarray = d$yr,
                     tickangle = 0)
      )
  })

  # --- Compare tab: a metric across several districts over time --------------
  # Home value (default $350k), guarded against an empty/blank field.
  cmp_home <- reactive({
    hv <- input$cmp_home_value
    if (is.null(hv) || is.na(hv)) 350000 else hv
  })

  output$cmp_title <- renderText({
    lab <- pv_metric_label(input$cmp_metric)
    if (identical(input$cmp_yaxis, "dollars")) {
      paste0(lab, " — annual taxes on a $",
             formatC(cmp_home(), format = "d", big.mark = ","), " home")
    } else {
      paste0(lab, " over time")
    }
  })

  output$compare_plot <- renderPlotly({
    validate(need(length(input$cmp_districts) > 0,
                  "Select one or more districts in the sidebar to compare."))
    metric  <- input$cmp_metric
    kind    <- pv_metrics()$kind[match(metric, pv_metrics()$key)]
    dollars <- identical(input$cmp_yaxis, "dollars")

    d <- finance |>
      filter(.data$geoid %in% input$cmp_districts) |>
      mutate(district = unname(district_name_by_geoid[.data$geoid]),
             yval = .data[[metric]]) |>
      arrange(.data$school_year)
    validate(need(any(is.finite(d$yval)),
                  "No data for that metric in the selected districts/years."))

    if (dollars) {
      # Annual taxes after each year's non-senior homestead exemption — whole
      # dollars in the thousands, so keep comma formatting (not $0.20 gridlines).
      d$yval <- taxes_on_home(d$yval, kind, d$school_year, cmp_home())
      yaxis_opts <- list(title = "Annual taxes ($)", tickprefix = "$",
                         tickformat = ",.0f", rangemode = "tozero")
      hov <- "%{fullData.name}<br>%{x}: $%{y:,.0f}<extra></extra>"
    } else if (identical(kind, "rate")) {
      # Rate metrics share the $/$100 styling of the rate-history chart:
      # dollar labels and gridlines every $0.20.
      yaxis_opts <- list(title = pv_metric_label(metric), tickprefix = "$",
                         tickformat = ".2f", tick0 = 0, dtick = 0.2,
                         rangemode = "tozero")
      hov <- "%{fullData.name}<br>%{x}: $%{y:.2f}<extra></extra>"
    } else {
      # Count metrics (penny counts) — plain integers, no dollar sign.
      yaxis_opts <- list(title = pv_metric_label(metric))
      hov <- "%{fullData.name}<br>%{x}: %{y}<extra></extra>"
    }

    # Abbreviated year labels: "05-06" instead of "2005-06".
    d$yr <- substr(d$school_year, 3, 7)

    # Grouping by district lets a click (or the search box) highlight one curve
    # and dim the rest; double-click clears it.
    sd <- highlight_key(d, ~district, group = "District")
    plot_ly(sd, x = ~yr, y = ~yval, color = ~district,
            type = "scatter", mode = "lines+markers", connectgaps = FALSE,
            hovertemplate = hov) |>
      layout(
        yaxis = yaxis_opts,
        # Force categorical axis (so "2005-06" is not parsed as a date) with
        # horizontal, abbreviated year labels.
        xaxis = list(title = "School year", type = "category", tickangle = 0,
                     categoryorder = "array",
                     categoryarray = substr(avail_years, 3, 7)),
        legend = list(orientation = "h", y = -0.2),
        hovermode = "x unified"
      ) |>
      highlight(on = "plotly_click", off = "plotly_doubleclick",
                selectize = TRUE, dynamic = FALSE, opacityDim = 0.12)
  })

  # --- Finance tab: filter the pre-aggregated PEIMS summary and draw ----------
  if (has_finance) {
    fin_rows <- reactive({
      req(input$fin_entity, input$fin_year, input$fin_basis)
      parts <- strsplit(input$fin_entity, "::", fixed = TRUE)[[1]]
      peims_summary |>
        filter(.data$district == parts[1], .data$type == parts[2],
               .data$school_year == input$fin_year,
               .data$basis == input$fin_basis)
    })

    output$fin_title <- renderText({
      d <- fin_rows()
      req(nrow(d) > 0)
      sprintf("%s, %s: every dollar in, every dollar out",
             d$district_name[[1]], input$fin_year)
    })

    output$fin_plot <- renderPlot({
      d <- fin_rows()
      validate(need(nrow(d) > 0,
                    "No PEIMS data for that district, year, and basis."))
      validate(need(
        requireNamespace("ggsankey", quietly = TRUE) &&
          requireNamespace("ggplot2", quietly = TRUE),
        paste(
          "This chart needs the ggsankey and ggplot2 packages.\n",
          "install.packages(\"ggplot2\")\n",
          'remotes::install_github("davidsjoberg/ggsankey")'
        )
      ))
      flows <- txschools::txs_peims_flow(
        d, axes = fin_axes_for(input$fin_axes), lump = input$fin_lump
      )
      txschools::txs_plot_peims_flow(flows) +
        ggplot2::labs(
          title = sprintf("%s: every dollar in, every dollar out",
                          d$district_name[[1]]),
          subtitle = sprintf("PEIMS %s, %s", input$fin_basis, input$fin_year)
        ) +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold", size = 15),
          plot.subtitle = ggplot2::element_text(color = "grey35", size = 10)
        )
    })
  }
}

shinyApp(ui, server)
