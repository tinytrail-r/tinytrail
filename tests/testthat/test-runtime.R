# tinytrail_the_end(): records the time between tinytrail() and the marker.

test_that("tinytrail_the_end() records script_runtime", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)
  writeLines("Package: testproject", "DESCRIPTION")

  tinytrail("test", name = "timed.R", auto = FALSE)
  expect_null(yaml::read_yaml("_tinytrail.yaml")$scripts[["timed.R"]]$script_runtime)

  expect_message(res <- tinytrail_the_end(), "timed.R: [0-9.]+ min runtime")
  expect_type(res, "double")
  reg <- yaml::read_yaml("_tinytrail.yaml")
  expect_match(reg$scripts[["timed.R"]]$script_runtime, "^[0-9.]+ min$")
})

test_that("a new run without tinytrail_the_end() drops the old runtime", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)
  writeLines("Package: testproject", "DESCRIPTION")

  tinytrail("test", name = "timed.R", auto = FALSE)
  suppressMessages(tinytrail_the_end())
  tinytrail("test", name = "timed.R", auto = FALSE)
  expect_null(yaml::read_yaml("_tinytrail.yaml")$scripts[["timed.R"]]$script_runtime)
})

test_that("tinytrail_the_end() works when the script is sourced", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)
  writeLines("Package: testproject", "DESCRIPTION")
  writeLines(c(
    "tinytrail::tinytrail('sourced', auto = FALSE)",
    "x <- 1",
    "tinytrail::tinytrail_the_end()"
  ), "script.R")

  expect_message(source("script.R"), "script.R: .* min runtime")
  expect_match(yaml::read_yaml("_tinytrail.yaml")$scripts[["script.R"]]$script_runtime,
               "^[0-9.]+ min$")
})

test_that("tinytrail_the_end() without tinytrail() writes a warning, not an error", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL,
                       .tinytrail_warned = NULL)
  writeLines("Package: testproject", "DESCRIPTION")

  expect_null(suppressMessages(tinytrail_the_end()))
  reg <- yaml::read_yaml("_tinytrail.yaml")
  expect_true(any(vapply(reg$scripts, \(s) grepl("tinytrail()", s$warning %||% "", fixed = TRUE),
                         logical(1))))
})

test_that("record_runtime is deprecated and ignored", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)
  writeLines("Package: testproject", "DESCRIPTION")

  expect_warning(tinytrail("test", name = "old.R", auto = FALSE, record_runtime = FALSE),
                 "tinytrail_the_end")
  expect_no_message(tinytrail("test", name = "plain.R", auto = FALSE), message = "source")
})

test_that("tinytrail_the_end() in main.R records main.R after sourcing other scripts", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)
  writeLines("Package: testproject", "DESCRIPTION")
  writeLines(c(
    "tinytrail::tinytrail('child', auto = FALSE)",
    "tinytrail::tinytrail_the_end()"
  ), "child.R")
  writeLines(c(
    "tinytrail::tinytrail('main', auto = FALSE)",
    "source('child.R')",
    "tinytrail::tinytrail_the_end()"
  ), "main.R")

  suppressMessages(source("main.R"))
  reg <- yaml::read_yaml("_tinytrail.yaml")
  expect_match(reg$scripts[["main.R"]]$script_runtime, "^[0-9.]+ min$")
  expect_match(reg$scripts[["child.R"]]$script_runtime, "^[0-9.]+ min$")
})
