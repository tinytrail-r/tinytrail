# Runtime tracking: which ways of running a script record script_runtime.

.runtime_project <- function(env = parent.frame()) {
  tmp <- withr::local_tempdir(.local_envir = env)
  writeLines("Package: testproject", file.path(tmp, "DESCRIPTION"))
  dir.create(file.path(tmp, "scripts"))
  writeLines(c(
    "tinytrail::tinytrail('Runtime test', auto = FALSE)",
    "x <- 1"
  ), file.path(tmp, "scripts", "timed.R"))
  tmp
}

.runtime_of <- function(dir, script) {
  reg <- yaml::read_yaml(file.path(dir, "_tinytrail.yaml"))
  reg$scripts[[script]]$script_runtime
}

test_that("source() records script_runtime", {
  tmp <- .runtime_project()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)

  expect_message(source(file.path("scripts", "timed.R")), "timed.R: .* min elapsed")
  expect_match(.runtime_of(tmp, "timed.R"), "^[0-9.]+ min$")
})

test_that("Rscript records script_runtime when R exits", {
  skip_on_cran()
  tmp <- .runtime_project()
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- withr::with_dir(tmp, withr::with_envvar(
    c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)),
    system2(rscript, file.path("scripts", "timed.R"), stdout = TRUE, stderr = TRUE)
  ))
  expect_true(any(grepl("timed.R: .* min elapsed", out)), info = paste(out, collapse = "\n"))
  expect_match(.runtime_of(tmp, "timed.R"), "^[0-9.]+ min$")
})

test_that("no runtime message when the script end cannot be detected", {
  tmp <- .runtime_project()
  withr::local_dir(tmp)
  withr::local_options(.tinytrail_current_script = NULL, .tinytrail_registry_path = NULL)

  # Not sourced and not knitted: no console note about source() any more
  expect_no_message(
    tinytrail("test", name = "plain.R", auto = FALSE),
    message = "requires source"
  )
  expect_null(.runtime_of(tmp, "plain.R"))
})
