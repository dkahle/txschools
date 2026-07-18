# Shared PEIMS fixtures for test-peims.R and test-peims-db.R.

peims_fake_downloads <- function() {
  tibble::tibble(
    source = "peims", year = 2024L, school_year = "2023-24",
    level = c("district", "charter"),
    data_type = c("actual", "budget"),
    dataset = NA_character_, file_format = "csv",
    label = c("District 2023-2024 Financial Actual Data",
              "Charter 2023-2024 Financial Budget Data"),
    method = "get",
    url = c("https://example.org/actget2024.zip",
            "https://example.org/charbud24.csv"),
    params = NA_character_
  )
}

peims_fake_http_download <- function(url, dest, ...) {
  src <- if (grepl("budget2024d", url)) {
    fixture_path("peims_codes_2024.zip")
  } else if (grepl("charbud", url)) {
    fixture_path("peims_budget_charter_small.csv")
  } else {
    fixture_path("peims_actual_district_small.zip")
  }
  file.copy(src, dest, overwrite = TRUE)
  list(path = dest, sha256 = sha256_file(dest),
       size_bytes = file.size(dest), content_type = "application/zip",
       retrieved_at = iso8601_now(), source_url = url)
}
