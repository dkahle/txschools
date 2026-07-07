# Regression tests against a real (live-fetched) 2025 TAPR report page
# and real broker responses, so parsing stays honest about what TEA
# actually serves.

test_that("entity names parse from the live 2025 report markup", {
  page <- parse_tapr_semantic_page(fixture_path("tapr_2025_student_live.html"))
  expect_equal(page$entity$entity_name, "CHINA SPRING EL")
  expect_equal(page$entity$district_name, "CHINA SPRING ISD")
  expect_equal(page$entity$county_name, "MCLENNAN COUNTY")
  expect_gt(length(page$tables), 0)
})

test_that("student datasets extract from the live 2025 report markup", {
  page <- parse_tapr_semantic_page(fixture_path("tapr_2025_student_live.html"))
  page$meta <- list(source_url = "fixture", retrieved_at = "fixture")
  out <- extract_student_dataset(page, key = "sex", year = 2025,
                                 level = "campus", geography = "161920102")
  expect_gt(nrow(out), 0)
  expect_setequal(unique(out$sex), c("Female", "Male"))
  expect_equal(unique(out$entity_name), "CHINA SPRING EL")
})

test_that("check_broker_data_response accepts CSV and rejects report pages", {
  csv <- fixture_path("broker_adv_state_staar1.csv")
  row <- list(source = "tapr", year = 2024L, level = "state", dataset = "STAAR1")
  expect_true(check_broker_data_response(csv, row))

  html <- withr::local_tempfile(fileext = ".csv")
  file.copy(fixture_path("broker_error_state_ref.html"), html,
            overwrite = TRUE)
  expect_error(
    check_broker_data_response(html, list(source = "tapr", year = 2024L,
                                          level = "state", dataset = "REF")),
    "report page instead of data"
  )
  expect_false(file.exists(html))
})
