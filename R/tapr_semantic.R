#' List semantic TAPR datasets
#'
#' Returns the stable dataset keys that [txs_get_tapr()] can return.
#'
#' @return A tibble with columns `key`, `label`, `page_source`, `grain`,
#'   and `columns`.
#' @export
txs_list_tapr_datasets <- function() {
  tibble::tibble(
    key = c(
      "grade",
      "ethnic",
      "sex",
      "cohorts",
      "program",
      "disability",
      "mobility",
      "attrition",
      "retention",
      "class_size",
      "staar_performance",
      "staar_progress",
      "bilingual_esl",
      "ccmr",
      "graduation",
      "attendance",
      "staff",
      "finance"
    ),
    label = c(
      "Student enrollment by grade",
      "Student ethnic distribution",
      "Student sex distribution",
      "Other student cohorts",
      "Students by instructional program",
      "Students with disabilities by primary disability",
      "Student mobility",
      "Student attrition",
      "Student retention",
      "Average class size",
      "STAAR performance",
      "STAAR progress",
      "Bilingual education and English as a second language",
      "College, career, and military readiness",
      "Graduation",
      "Attendance",
      "Staff information",
      "Finance"
    ),
    page_source = c(
      rep("student", 10),
      "staar_performance",
      "staar_progress",
      "bilingual_esl",
      "ccmr",
      "graduation",
      "attendance",
      "staff",
      "finance"
    ),
    grain = c(
      "campus/district-year grade",
      "campus/district-year ethnicity",
      "campus/district-year sex",
      "campus/district-year cohort",
      "campus/district-year program",
      "campus/district-year disability",
      "campus/district-year mobility measure",
      "campus/district-year attrition measure",
      "campus/district-year retention measure",
      "campus/district-year class-size measure",
      rep("campus/district-year report row and comparison group", 8)
    ),
    columns = c(
      rep(
        paste(
          c(
            "year", "school_year", "level", "geography", "basis",
            "count", "campus_percent", "district_percent", "state_percent"
          ),
          collapse = ", "
        ),
        9
      ),
      paste(
        c(
          "year", "school_year", "level", "geography", "basis",
          "class_size", "campus_class_size", "district_class_size",
          "state_class_size"
        ),
        collapse = ", "
      ),
      rep(
        paste(
          c(
            "year", "school_year", "level", "geography", "page_source",
            "table_index", "row_label", "column", "value",
            "masked", "mask_code"
          ),
          collapse = ", "
        ),
        8
      )
    )
  )
}

collect_tapr_semantic <- function(years, level, geography, datasets,
                                  cache, refresh, timeout, verbose) {
  out <- tapr_empty_result(datasets)
  manifest <- list()

  for (yr in years) {
    for (geo in geography) {
      pages <- fetch_tapr_semantic_pages(
        year = yr, level = level, geography = geo,
        datasets = datasets, cache = cache, refresh = refresh,
        timeout = timeout, verbose = verbose
      )
      extracted <- extract_tapr_semantic_pages(
        pages = pages, year = yr, level = level,
        geography = geo, datasets = datasets
      )
      for (key in names(out)) {
        out[[key]] <- dplyr::bind_rows(out[[key]], extracted[[key]])
      }
      manifest[[length(manifest) + 1L]] <- tapr_pages_manifest(
        pages, year = yr, level = level, geography = geo
      )
    }
  }

  attr(out, "txschools") <- list(
    source = "tapr",
    years = years,
    school_years = vapply(years, year_label, character(1)),
    level = level,
    geography = geography,
    datasets = datasets,
    pages = dplyr::bind_rows(manifest),
    masking_values = mask_codes()
  )
  class(out) <- c("tapr", "list")
  out
}

fetch_tapr_semantic_pages <- function(year, level, geography, datasets,
                                      cache, refresh, timeout, verbose) {
  dataset_catalog <- txs_list_tapr_datasets()
  requested_sources <- unique(dataset_catalog$page_source[
    dataset_catalog$key %in% datasets
  ])

  seed <- download_tapr_semantic_page(
    year = year, level = level, geography = geography,
    page_source = "student", prgopt = "reports/tapr/student.sas",
    cache = cache, refresh = refresh, timeout = timeout, verbose = verbose
  )

  pages <- list(student = seed)
  discovered <- discover_tapr_page_sources(seed)
  if (nrow(discovered)) {
    for (i in seq_len(nrow(discovered))) {
      src <- discovered$page_source[[i]]
      if (identical(src, "student") || !src %in% requested_sources) next
      pages[[src]] <- download_tapr_semantic_page(
        year = year, level = level, geography = geography,
        page_source = src, prgopt = discovered$prgopt[[i]],
        cache = cache, refresh = refresh, timeout = timeout,
        verbose = verbose
      )
    }
  }

  # If a user explicitly asks for a known page but the navigation did not
  # reveal it, try the package's best-known public route. Failures are kept
  # local to that page so one missing TEA route does not abort the pull.
  fallback <- tapr_page_catalog()
  missing <- setdiff(requested_sources, names(pages))
  for (src in missing) {
    hit <- fallback[fallback$page_source == src, , drop = FALSE]
    if (!nrow(hit)) next
    page <- tryCatch(
      download_tapr_semantic_page(
        year = year, level = level, geography = geography,
        page_source = src, prgopt = hit$prgopt[[1]],
        cache = cache, refresh = refresh, timeout = timeout,
        verbose = verbose
      ),
      error = function(e) NULL
    )
    if (!is.null(page)) pages[[src]] <- page
  }

  pages
}

tapr_page_catalog <- function() {
  tibble::tibble(
    page_source = c(
      "student",
      "staar_performance",
      "staar_progress",
      "bilingual_esl",
      "ccmr",
      "graduation",
      "attendance",
      "staff",
      "finance"
    ),
    prgopt = c(
      "reports/tapr/student.sas",
      "reports/tapr/perf_addsg.sas",
      "reports/tapr/progress.sas",
      "reports/tapr/biling.sas",
      "reports/tapr/ccmr.sas",
      "reports/tapr/grad.sas",
      "reports/tapr/attendance.sas",
      "reports/tapr/staff.sas",
      "reports/tapr/finance.sas"
    )
  )
}

download_tapr_semantic_page <- function(year, level, geography, page_source,
                                        prgopt, cache, refresh, timeout,
                                        verbose) {
  url <- tapr_html_report_url(
    year = year, level = level, geography = geography, prgopt = prgopt
  )
  filename <- tapr_html_report_filename(level, geography, page_source)
  dest <- cache_path("tapr", year, level, "html", file = filename)
  if (!cache) dest <- temp_download_path(filename)

  used_cache <- FALSE
  if (cache && !refresh && file.exists(dest)) {
    if (verbose) cli::cli_alert_info(
      "Using cached TAPR {tapr_page_message_label(page_source)} page"
    )
    used_cache <- TRUE
    meta <- read_sidecar(dest) %||% list(
      source_url = url,
      retrieved_at = NA_character_,
      sha256 = sha256_file(dest),
      size_bytes = file.size(dest),
      content_type = NA_character_
    )
  } else {
    if (verbose) {
      source_link <- cli::style_hyperlink("source", url)
      cli::cli_alert_info(
        "Downloading TAPR {tapr_page_message_label(page_source)} page ({source_link})"
      )
    }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    info <- http_download(url, dest, timeout = timeout)
    meta <- list(
      source = "tapr",
      year = year,
      school_year = year_label(year),
      level = level,
      geography = as.character(geography),
      page_source = page_source,
      prgopt = prgopt,
      data_type = "semantic",
      file_format = "html",
      source_url = url,
      retrieved_at = info$retrieved_at,
      sha256 = info$sha256,
      size_bytes = info$size_bytes,
      content_type = info$content_type
    )
    if (cache) write_sidecar(dest, meta)
  }

  page <- parse_tapr_semantic_page(dest)
  page$page_source <- page_source
  page$prgopt <- prgopt
  page$path <- dest
  page$meta <- c(meta, list(used_cache = used_cache))
  page
}

tapr_page_message_label <- function(page_source) {
  switch(
    page_source,
    student = "student information",
    staar_performance = "STAAR performance",
    staar_progress = "STAAR progress",
    bilingual_esl = "bilingual/ESL",
    ccmr = "college, career, and military readiness",
    graduation = "graduation",
    attendance = "attendance",
    staff = "staff",
    finance = "finance",
    gsub("_", " ", page_source, fixed = TRUE)
  )
}

parse_tapr_semantic_page <- function(path) {
  html <- tryCatch(rvest::read_html(path), error = function(e) NULL)
  if (is.null(html)) {
    return(list(tables = list(), links = tibble::tibble(), entity = list()))
  }

  tables <- tryCatch(
    rvest::html_table(html, fill = TRUE, trim = FALSE),
    error = function(e) list()
  )
  tables <- lapply(tables, clean_tapr_table)
  tables <- tables[vapply(tables, nrow, integer(1)) > 0L]

  anchors <- rvest::html_elements(html, "a")
  hrefs <- rvest::html_attr(anchors, "href")
  labels <- clean_tapr_text(rvest::html_text(anchors))
  links <- tibble::tibble(
    label = labels,
    href = hrefs
  )

  list(
    tables = tables,
    links = links,
    entity = parse_tapr_entity(html)
  )
}

clean_tapr_table <- function(tab) {
  tab <- as.data.frame(tab, stringsAsFactors = FALSE, check.names = FALSE)
  tab[] <- lapply(tab, clean_tapr_text)
  tab <- tab[rowSums(as.matrix(tab != "")) > 0, , drop = FALSE]
  tibble::as_tibble(tab, .name_repair = "minimal")
}

clean_tapr_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\u00a0", " ", x, fixed = TRUE)
  x <- gsub("[[:space:]]+", " ", x)
  trimws(x)
}

parse_tapr_entity <- function(html) {
  candidates <- clean_tapr_text(c(
    rvest::html_text(rvest::html_elements(html, "h1, h2, h3")),
    rvest::html_text(rvest::html_elements(html, "title"))
  ))
  candidates <- candidates[nzchar(candidates)]
  entity_line <- candidates[grepl("\\([0-9]{6,9}\\)", candidates)][1] %||%
    candidates[1] %||% NA_character_

  entity_name <- district_name <- county_name <- NA_character_
  if (!is.na(entity_line)) {
    if (grepl("\\([0-9]{6,9}\\)", entity_line)) {
      entity_name <- clean_tapr_text(sub("\\s*\\([0-9]{6,9}\\).*", "", entity_line))
      rest <- clean_tapr_text(sub("^.*\\([0-9]{6,9}\\)\\s*-\\s*", "", entity_line))
      pieces <- strsplit(rest, "\\s+-\\s+")[[1]]
      if (length(pieces) >= 1L) district_name <- pieces[[1]]
      if (length(pieces) >= 2L) county_name <- pieces[[2]]
    } else {
      entity_name <- entity_line
    }
  }
  list(
    entity_name = entity_name,
    district_name = district_name,
    county_name = county_name
  )
}

discover_tapr_page_sources <- function(page) {
  if (!length(page$links) || !nrow(page$links)) {
    return(tibble::tibble(page_source = character(), prgopt = character()))
  }
  hrefs <- page$links$href
  hrefs <- hrefs[!is.na(hrefs) & nzchar(hrefs)]
  prgopts <- stringr::str_match(hrefs, "[?&]prgopt=([^&#]+)")[, 2]
  prgopts <- utils::URLdecode(prgopts[!is.na(prgopts)])
  prgopts <- prgopts[grepl("^reports/tapr/.+\\.sas$", prgopts)]
  if (!length(prgopts)) {
    return(tibble::tibble(page_source = character(), prgopt = character()))
  }
  out <- tibble::tibble(
    page_source = vapply(prgopts, tapr_page_source_from_prgopt, character(1)),
    prgopt = prgopts
  )
  out[!duplicated(out$page_source), , drop = FALSE]
}

tapr_page_source_from_prgopt <- function(prgopt) {
  base <- tolower(tools::file_path_sans_ext(basename(prgopt)))
  if (base %in% c("student")) return("student")
  if (grepl("perf", base)) return("staar_performance")
  if (grepl("progress|growth", base)) return("staar_progress")
  if (grepl("bil|esl|eb", base)) return("bilingual_esl")
  if (grepl("ccmr|college|career|military", base)) return("ccmr")
  if (grepl("grad", base)) return("graduation")
  if (grepl("attend", base)) return("attendance")
  if (grepl("staff", base)) return("staff")
  if (grepl("fin|expend|revenue", base)) return("finance")
  gsub("[^a-z0-9]+", "_", base)
}

extract_tapr_semantic_pages <- function(pages, year, level, geography,
                                        datasets) {
  out <- tapr_empty_result(datasets)
  catalog <- txs_list_tapr_datasets()
  for (key in datasets) {
    source <- catalog$page_source[match(key, catalog$key)]
    if (identical(source, "student")) {
      out[[key]] <- extract_student_dataset(
        pages$student, key = key, year = year,
        level = level, geography = geography
      )
    } else if (!is.null(pages[[source]])) {
      out[[key]] <- extract_generic_page_dataset(
        pages[[source]], key = key, year = year,
        level = level, geography = geography
      )
    }
  }
  out
}

extract_student_dataset <- function(page, key, year, level, geography) {
  tab <- find_student_table(page)
  if (is.null(tab)) return(tapr_empty_student_dataset(key))
  tab <- normalize_student_table(tab)
  if (!nrow(tab)) return(tapr_empty_student_dataset(key))

  sections <- label_student_sections(tab$measure)
  target <- student_dataset_section(key)
  keep <- !is.na(sections) & sections == target
  if (!any(keep)) {
    keep <- fallback_student_section(tab$measure, key)
  }
  rows <- tab[keep, , drop = FALSE]
  rows <- rows[!student_skip_measure(rows$measure), , drop = FALSE]
  if (!nrow(rows)) return(tapr_empty_student_dataset(key))

  value_sets <- student_value_sets(names(rows))
  entity <- page$entity %||% list()
  out <- list()
  dim_col <- student_dimension_column(key)

  for (i in seq_len(nrow(rows))) {
    for (set in value_sets) {
      rec <- tibble::tibble(
        year = as.integer(year),
        school_year = year_label(year),
        level = level,
        geography = as.character(geography),
        entity_name = entity$entity_name %||% NA_character_,
        district_name = entity$district_name %||% NA_character_,
        county_name = entity$county_name %||% NA_character_,
        source_url = page$meta$source_url %||% NA_character_,
        retrieved_at = page$meta$retrieved_at %||% NA_character_,
        basis = set$basis
      )
      rec[[dim_col]] <- rows$measure[[i]]
      if (identical(key, "class_size")) {
        rec$campus_class_size <- rows[[set$count]][[i]] %||% NA_character_
        rec$district_class_size <- rows[[set$district_percent]][[i]] %||% NA_character_
        rec$state_class_size <- rows[[set$state_percent]][[i]] %||% NA_character_
      } else {
        rec$count <- rows[[set$count]][[i]] %||% NA_character_
        rec$campus_percent <- rows[[set$campus_percent]][[i]] %||% NA_character_
        rec$district_percent <- rows[[set$district_percent]][[i]] %||% NA_character_
        rec$state_percent <- rows[[set$state_percent]][[i]] %||% NA_character_
      }
      out[[length(out) + 1L]] <- rec
    }
  }

  out <- dplyr::bind_rows(out)
  if (identical(key, "class_size")) {
    coerce_tapr_student_values(
      out,
      c("campus_class_size", "district_class_size", "state_class_size"),
      integer_cols = character(),
      percent_cols = character()
    )
  } else {
    coerce_tapr_student_values(
      out,
      c("count", "campus_percent", "district_percent", "state_percent")
    )
  }
}

find_student_table <- function(page) {
  tables <- page$tables %||% list()
  if (!length(tables)) return(NULL)
  has_student <- vapply(tables, function(tab) {
    any(grepl("^Total Students\\b", unlist(tab), ignore.case = TRUE)) ||
      any(grepl("^Students by Grade$", unlist(tab), ignore.case = TRUE))
  }, logical(1))
  idx <- which(has_student)[1]
  if (is.na(idx)) return(NULL)
  tables[[idx]]
}

normalize_student_table <- function(tab) {
  tab <- clean_tapr_table(tab)
  if (!nrow(tab)) return(tab)
  n <- ncol(tab)
  if (n >= 9L) {
    tab <- tab[seq_len(9L)]
    names(tab) <- c(
      "measure",
      "membership_count", "membership_percent",
      "membership_district_percent", "membership_state_percent",
      "enrollment_count", "enrollment_percent",
      "enrollment_district_percent", "enrollment_state_percent"
    )
  } else if (n >= 5L) {
    tab <- tab[seq_len(5L)]
    names(tab) <- c(
      "measure", "reported_count", "reported_percent",
      "reported_district_percent", "reported_state_percent"
    )
  } else if (n >= 3L) {
    tab <- tab[seq_len(3L)]
    names(tab) <- c("measure", "reported_count", "reported_percent")
    tab$reported_district_percent <- NA_character_
    tab$reported_state_percent <- NA_character_
  } else {
    return(tibble::tibble())
  }
  tab$measure <- clean_tapr_text(tab$measure)
  tab[nzchar(tab$measure), , drop = FALSE]
}

student_value_sets <- function(nms) {
  if (all(c(
    "membership_count", "membership_percent",
    "membership_district_percent", "membership_state_percent",
    "enrollment_count", "enrollment_percent",
    "enrollment_district_percent", "enrollment_state_percent"
  ) %in% nms)) {
    return(list(
      list(
        basis = "membership",
        count = "membership_count",
        campus_percent = "membership_percent",
        district_percent = "membership_district_percent",
        state_percent = "membership_state_percent"
      ),
      list(
        basis = "enrollment",
        count = "enrollment_count",
        campus_percent = "enrollment_percent",
        district_percent = "enrollment_district_percent",
        state_percent = "enrollment_state_percent"
      )
    ))
  }
  list(list(
    basis = "reported",
    count = "reported_count",
    campus_percent = "reported_percent",
    district_percent = "reported_district_percent",
    state_percent = "reported_state_percent"
  ))
}

label_student_sections <- function(measure) {
  out <- rep(NA_character_, length(measure))
  current <- NA_character_
  for (i in seq_along(measure)) {
    m <- clean_tapr_text(measure[[i]])
    section <- student_heading_section(m)
    if (!is.na(section)) {
      current <- section
      next
    }
    out[[i]] <- current
  }
  out
}

student_section_headings <- function() {
  c(
    "Students by Grade" = "grade",
    "Ethnic Distribution" = "ethnic",
    "Sex" = "sex",
    "Other Student Cohorts" = "cohorts",
    "Students by Instructional Program" = "program",
    "Students with Disabilities by Type of Primary Disability" = "disability",
    "Mobility" = "mobility",
    "Student Attrition" = "attrition",
    "Retention" = "retention",
    "Average Class Size" = "class_size"
  )
}

student_heading_section <- function(measure) {
  m <- clean_tapr_text(measure)
  if (identical(m, "Students by Grade")) return("grade")
  if (identical(m, "Ethnic Distribution")) return("ethnic")
  if (identical(m, "Sex")) return("sex")
  if (identical(m, "Other Student Cohorts")) return("cohorts")
  if (grepl("Instructional Program", m, ignore.case = TRUE)) return("program")
  if (grepl("Disabilities by Type", m, ignore.case = TRUE)) return("disability")
  if (grepl("^Mobility\\b", m, ignore.case = TRUE)) return("mobility")
  if (identical(m, "Student Attrition")) return("attrition")
  if (identical(m, "Retention")) return("retention")
  if (identical(m, "Average Class Size")) return("class_size")
  NA_character_
}

student_dataset_section <- function(key) {
  switch(
    key,
    grade = "grade",
    ethnic = "ethnic",
    sex = "sex",
    cohorts = "cohorts",
    program = "program",
    disability = "disability",
    mobility = "mobility",
    attrition = "attrition",
    retention = "retention",
    class_size = "class_size"
  )
}

student_dimension_column <- function(key) {
  switch(
    key,
    grade = "grade",
    ethnic = "ethnic",
    sex = "sex",
    cohorts = "cohort",
    program = "program",
    disability = "disability",
    mobility = "mobility",
    attrition = "attrition",
    retention = "retention",
    class_size = "class_size"
  )
}

fallback_student_section <- function(measure, key) {
  measure <- clean_tapr_text(measure)
  switch(
    key,
    grade = grepl("^Grade\\b", measure),
    ethnic = measure %in% c(
      "African American", "Hispanic", "White", "American Indian",
      "Asian", "Pacific Islander", "Two or More Races"
    ),
    sex = measure %in% c("Female", "Male"),
    cohorts = measure %in% c(
      "Total Students", "Economically Disadvantaged",
      "Non-Educationally Disadvantaged", "Section 504 Students",
      "EB Students/EL", "Students w/ Disciplinary Placements",
      "Students w/ Dyslexia", "Foster Care", "Homeless", "Immigrant",
      "Migrant", "Title I", "Military Connected", "At-Risk"
    ),
    program = measure %in% c(
      "Bilingual/ESL Education", "Career and Technical Education",
      "Career and Technical Education (9-12 grades only)",
      "Gifted and Talented Education", "Special Education"
    ),
    disability = grepl("Disabilit", measure),
    mobility = grepl("Mobile|Mobility", measure, ignore.case = TRUE),
    attrition = grepl("Attrit", measure, ignore.case = TRUE),
    retention = grepl("Retain|Retention", measure, ignore.case = TRUE),
    class_size = grepl("Class Size|Average", measure, ignore.case = TRUE),
    rep(FALSE, length(measure))
  )
}

student_skip_measure <- function(measure) {
  measure <- clean_tapr_text(measure)
  !nzchar(measure) |
    measure %in% c(
      "Student Information", "Campus", "Count", "Percent", "District",
      "State"
    ) |
    !is.na(vapply(measure, student_heading_section, character(1)))
}

extract_generic_page_dataset <- function(page, key, year, level, geography) {
  tables <- page$tables %||% list()
  if (!length(tables)) return(tapr_empty_generic_dataset(key))
  entity <- page$entity %||% list()
  out <- list()

  for (table_index in seq_along(tables)) {
    tab <- tables[[table_index]]
    if (!nrow(tab) || ncol(tab) < 2L) next
    nms <- names(tab)
    nms[!nzchar(nms)] <- paste0("V", which(!nzchar(nms)))
    names(tab) <- nms
    row_label_col <- names(tab)[[1]]
    value_cols <- setdiff(names(tab), row_label_col)
    for (i in seq_len(nrow(tab))) {
      row_label <- clean_tapr_text(tab[[row_label_col]][[i]])
      if (!nzchar(row_label)) next
      for (col in value_cols) {
        value <- clean_tapr_text(tab[[col]][[i]])
        if (!nzchar(value)) next
        rec <- tibble::tibble(
          year = as.integer(year),
          school_year = year_label(year),
          level = level,
          geography = as.character(geography),
          entity_name = entity$entity_name %||% NA_character_,
          district_name = entity$district_name %||% NA_character_,
          county_name = entity$county_name %||% NA_character_,
          source_url = page$meta$source_url %||% NA_character_,
          retrieved_at = page$meta$retrieved_at %||% NA_character_,
          page_source = page$page_source %||% key,
          table_index = as.integer(table_index),
          row_label = row_label,
          column = clean_tapr_text(col),
          value = value
        )
        out[[length(out) + 1L]] <- rec
      }
    }
  }
  if (!length(out)) return(tapr_empty_generic_dataset(key))
  coerce_tapr_generic_value(dplyr::bind_rows(out))
}

coerce_tapr_student_values <- function(df, cols,
                                       integer_cols = "count",
                                       percent_cols = grep("percent$", cols, value = TRUE)) {
  for (col in cols) {
    x <- df[[col]]
    parsed <- parse_tapr_values(
      x,
      percent = col %in% percent_cols,
      integer = col %in% integer_cols
    )
    df[[col]] <- parsed$value
    df[[paste0(col, "_masked")]] <- parsed$masked
    df[[paste0(col, "_mask_code")]] <- parsed$mask_code
  }
  df
}

coerce_tapr_generic_value <- function(df) {
  parsed <- parse_tapr_values(df$value, percent = grepl("%", df$value))
  df$value <- parsed$value
  df$masked <- parsed$masked
  df$mask_code <- parsed$mask_code
  df
}

parse_tapr_values <- function(x, percent = FALSE, integer = FALSE) {
  x_chr <- clean_tapr_text(x)
  masked <- x_chr %in% mask_codes()
  numeric_input <- ifelse(masked, NA_character_, x_chr)
  has_percent <- grepl("%", numeric_input, fixed = TRUE)
  numeric_input <- gsub("%", "", numeric_input, fixed = TRUE)
  numeric_input <- gsub(",", "", numeric_input, fixed = TRUE)
  numeric_input[!nzchar(numeric_input)] <- NA_character_
  value <- suppressWarnings(as.numeric(numeric_input))
  percent <- rep_len(percent, length(value)) | has_percent
  value[percent & !is.na(value)] <- value[percent & !is.na(value)] / 100
  if (isTRUE(integer)) {
    value <- as.integer(round(value))
  }
  tibble::tibble(
    value = value,
    masked = masked,
    mask_code = ifelse(masked, x_chr, NA_character_)
  )
}

tapr_empty_result <- function(datasets) {
  out <- stats::setNames(vector("list", length(datasets)), datasets)
  catalog <- txs_list_tapr_datasets()
  for (key in datasets) {
    source <- catalog$page_source[match(key, catalog$key)]
    out[[key]] <- if (identical(source, "student")) {
      tapr_empty_student_dataset(key)
    } else {
      tapr_empty_generic_dataset(key)
    }
  }
  out
}

tapr_empty_student_dataset <- function(key) {
  dim_col <- student_dimension_column(key)
  out <- tibble::tibble(
    year = integer(),
    school_year = character(),
    level = character(),
    geography = character(),
    entity_name = character(),
    district_name = character(),
    county_name = character(),
    source_url = character(),
    retrieved_at = character(),
    basis = character()
  )
  out[[dim_col]] <- character()
  value_cols <- if (identical(key, "class_size")) {
    c("campus_class_size", "district_class_size", "state_class_size")
  } else {
    c("count", "campus_percent", "district_percent", "state_percent")
  }
  for (col in value_cols) {
    out[[col]] <- if (identical(col, "count")) integer() else numeric()
    out[[paste0(col, "_masked")]] <- logical()
    out[[paste0(col, "_mask_code")]] <- character()
  }
  out
}

tapr_empty_generic_dataset <- function(key) {
  tibble::tibble(
    year = integer(),
    school_year = character(),
    level = character(),
    geography = character(),
    entity_name = character(),
    district_name = character(),
    county_name = character(),
    source_url = character(),
    retrieved_at = character(),
    page_source = character(),
    table_index = integer(),
    row_label = character(),
    column = character(),
    value = numeric(),
    masked = logical(),
    mask_code = character()
  )
}

tapr_pages_manifest <- function(pages, year, level, geography) {
  if (!length(pages)) {
    return(tibble::tibble(
      year = integer(), school_year = character(), level = character(),
      geography = character(), page_source = character(), source_url = character(),
      retrieved_at = character(), sha256 = character(), cache_path = character(),
      used_cache = logical(), table_count = integer()
    ))
  }
  dplyr::bind_rows(lapply(pages, function(page) {
    tibble::tibble(
      year = as.integer(year),
      school_year = year_label(year),
      level = level,
      geography = as.character(geography),
      page_source = page$page_source %||% NA_character_,
      source_url = page$meta$source_url %||% NA_character_,
      retrieved_at = page$meta$retrieved_at %||% NA_character_,
      sha256 = page$meta$sha256 %||% NA_character_,
      cache_path = page$path %||% NA_character_,
      used_cache = isTRUE(page$meta$used_cache),
      table_count = length(page$tables %||% list())
    )
  }))
}

#' Write semantic TAPR datasets to DuckDB
#'
#' @param x A `tapr` object returned by [txs_get_tapr()].
#' @param db A DuckDB file path or an existing DBI connection.
#' @param overwrite If `TRUE`, replace existing tables with the same names.
#' @return Invisibly returns `x`.
#' @export
txs_write_tapr_db <- function(x, db, overwrite = FALSE) {
  if (!inherits(x, "tapr")) {
    stop("`x` must be a `tapr` object.", call. = FALSE)
  }
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package `DBI` is required to write TAPR data to a database.",
         call. = FALSE)
  }

  disconnect <- FALSE
  con <- db
  if (is.character(db) && length(db) == 1L) {
    if (!requireNamespace("duckdb", quietly = TRUE)) {
      stop("Package `duckdb` is required when `db` is a file path.",
           call. = FALSE)
    }
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db)
    disconnect <- TRUE
  }
  if (disconnect) {
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  }

  for (nm in names(x)) {
    write_tapr_db_table(con, nm, x[[nm]], overwrite = overwrite)
  }
  write_tapr_db_table(
    con, "_tapr_catalog", txs_list_tapr_datasets(),
    overwrite = overwrite
  )
  meta <- attr(x, "txschools")$pages %||% tibble::tibble()
  write_tapr_db_table(
    con, "_tapr_pages", meta,
    overwrite = overwrite
  )
  invisible(x)
}

write_tapr_db_table <- function(con, name, value, overwrite) {
  if (DBI::dbExistsTable(con, name) && !isTRUE(overwrite)) {
    stop("Database table already exists: ", name, call. = FALSE)
  }
  DBI::dbWriteTable(con, name, as.data.frame(value), overwrite = overwrite)
}

#' @export
print.tapr <- function(x, ...) {
  cat("<tapr>\n")
  for (nm in names(x)) {
    cat("* ", nm, ": ", nrow(x[[nm]]), " row", if (nrow(x[[nm]]) == 1L) "" else "s", "\n", sep = "")
  }
  invisible(x)
}
