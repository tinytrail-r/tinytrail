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

test_that(".knitr_source_name() maps knitr's working copies back to the source file", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, c("rapport.qmd", "notes.Rmd", "clean.R")))

  expect_equal(.knitr_source_name(file.path(tmp, "rapport.rmarkdown")), "rapport.qmd")
  expect_equal(.knitr_source_name(file.path(tmp, "notes.rmarkdown")), "notes.Rmd")
  expect_equal(.knitr_source_name(file.path(tmp, "clean.spin.Rmd")), "clean.R")
  expect_equal(.knitr_source_name(file.path(tmp, "clean.rmarkdown")), "clean.R")
  # Ordinary inputs are left alone
  expect_equal(.knitr_source_name(file.path(tmp, "notes.Rmd")), "notes.Rmd")
  # Source file not found: fall back to the most likely name
  expect_equal(.knitr_source_name(file.path(tmp, "missing.rmarkdown")), "missing.qmd")
})

test_that("a Quarto-style render records report.qmd, not report.rmarkdown", {
  skip_if_not_installed("knitr")
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  local_clean_options()
  writeLines("Package: testproject", "DESCRIPTION")
  doc <- c("```{r}", "tinytrail::tinytrail('report', auto = FALSE)", "```")
  writeLines(doc, "report.qmd")
  # Quarto knits a copy of the .qmd with the .rmarkdown extension
  writeLines(doc, "report.rmarkdown")

  suppressMessages(knitr::knit("report.rmarkdown", output = "report.md", quiet = TRUE))

  reg <- yaml::read_yaml("_tinytrail.yaml")
  expect_true("report.qmd" %in% names(reg$scripts))
  expect_false("report.rmarkdown" %in% names(reg$scripts))
})

test_that("rendering a plain .R script records script.R, not script.spin.Rmd", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available())
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  local_clean_options()
  writeLines("Package: testproject", "DESCRIPTION")
  writeLines("tinytrail::tinytrail('spun', auto = FALSE)", "spun.R")

  suppressMessages(rmarkdown::render("spun.R", output_format = "md_document", quiet = TRUE))

  reg <- yaml::read_yaml("_tinytrail.yaml")
  expect_true("spun.R" %in% names(reg$scripts))
  expect_false("spun.spin.Rmd" %in% names(reg$scripts))
})
