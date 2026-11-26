# Tests for call-stack source() detection (issue #9).

local_clean_options <- function(envir = parent.frame()) {
  withr::local_options(
    .tinytrail_current_script = NULL,
    .tinytrail_registry_path  = NULL,
    .local_envir = envir
  )
}

recorded_outputs <- function(script) {
  reg <- yaml::read_yaml("_tinytrail.yaml")
  unlist(reg$scripts[[script]]$outputs)
}

test_that(".source_frame_idx() handles multiline anonymous functions on the stack", {
  idx <- (function() {
    x <- 1
    .source_frame_idx()
  })()
  expect_identical(idx, integer(0))
})

test_that("tinytrail_write() records output inside a multiline anonymous function", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  local_clean_options()
  tinytrail(name = "reprex.R", description = "test", data_source = "none",
            auto = FALSE)

  expect_no_message(
    (function() {
      x <- mtcars
      write.csv(x, tinytrail_write("out.csv"), row.names = FALSE)
    })(),
    message = "could not record"
  )
  expect_true(file.exists("out.csv"))
  expect_true(any(grepl("out.csv", recorded_outputs("reprex.R"), fixed = TRUE)))
})

test_that("source() detection still finds the script name", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  local_clean_options()
  writeLines(c(
    'tinytrail(description = "sourced", data_source = "none",',
    '          auto = FALSE)',
    '(function() {',
    '  x <- 1',
    '  tinytrail_write("sourced-out.csv")',
    '})()'
  ), "my_script.R")

  expect_no_message(source("my_script.R", local = new.env(parent = asNamespace("tinytrail"))), message = "could not record")
  expect_equal(getOption(".tinytrail_current_script"), "my_script.R")
  expect_true(any(grepl("sourced-out.csv", recorded_outputs("my_script.R"), fixed = TRUE)))
})

test_that("base::source() is detected as a source() call", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  local_clean_options()
  writeLines(c(
    'tinytrail(description = "sourced", data_source = "none",',
    '          auto = FALSE)'
  ), "ns_script.R")

  base::source("ns_script.R", local = new.env(parent = asNamespace("tinytrail")))
  expect_equal(getOption(".tinytrail_current_script"), "ns_script.R")
})
