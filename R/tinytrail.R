# Public API: tinytrail(), tinytrail_write(), tinytrail_dict()
#
# Sub-functions used exclusively by the public API are defined first.

.build_script_entry <- function(description, data_source, pin_to_top, first_run, now) {
  entry <- list(
    description = description,
    first_run   = first_run %||% now,
    latest_run  = now,
    outputs     = "none"
  )
  if (!is.null(data_source)) entry$data_source <- data_source
  if (pin_to_top) entry$pin_to_top <- TRUE
  entry
}

.sort_scripts <- function(scripts) {
  all_names <- names(scripts)
  pinned    <- all_names[vapply(scripts[all_names], \(s) isTRUE(s$pin_to_top), logical(1))]
  rest      <- sort(all_names[!all_names %in% pinned])
  lapply(scripts[c(pinned, rest)], .order_registry_entry)
}

.setup_runtime_hook <- function(script_name, registry_path, start_sec, source_idx) {
  record_elapsed <- local({
    script_name   <- script_name
    registry_path <- registry_path
    start_sec     <- start_sec
    function() {
      elapsed_min <- round((as.numeric(Sys.time()) - start_sec) / 60, 1)
      if (!file.exists(registry_path)) return()
      registry <- yaml::read_yaml(registry_path)
      if (is.null(registry$scripts[[script_name]])) return()
      registry$scripts[[script_name]]$script_runtime <- sprintf("%.1f min", elapsed_min)
      registry$scripts <- lapply(registry$scripts, .order_registry_entry)
      .write_registry(registry, registry_path)
      message(script_name, ": ", sprintf("%.1f min", elapsed_min), " elapsed")
    }
  })

  if (length(source_idx) > 0L) {
    # source() / RStudio "Source": record when the source() call returns.
    idx_val <- source_idx[length(source_idx)]
    do.call(
      on.exit,
      list(bquote(.(record_elapsed)()), add = TRUE, after = TRUE),
      envir = sys.frame(idx_val)
    )
  } else if (.in_knitr()) {
    # knitr::knit(), rmarkdown::render(), quarto render, RStudio "Knit"/"Render":
    # record when the document has finished. knitr restores its hooks after
    # each document, so this does not leak into later renders.
    old_hook <- knitr::knit_hooks$get("document")
    knitr::knit_hooks$set(document = local({
      record_elapsed <- record_elapsed
      old_hook       <- old_hook
      function(x) {
        record_elapsed()
        if (is.function(old_hook)) old_hook(x) else x
      }
    }))
  } else if (!interactive()) {
    # Rscript script.R / R CMD BATCH: record when R exits. The anchor
    # environment is kept alive in .runtime_anchors so the finalizer only runs
    # at exit, not at an earlier garbage collection.
    anchor <- new.env(parent = emptyenv())
    reg.finalizer(anchor, function(e) try(record_elapsed(), silent = TRUE), onexit = TRUE)
    .runtime_anchors[[script_name]] <- anchor
  }
  # Interactive line-by-line / chunk-by-chunk runs (including RStudio
  # "Run All") have no end point to hook into, so nothing is recorded.
  # Documented under "Runtime tracking" in ?tinytrail.
  invisible(NULL)
}

#' Register a script in the project trail
#'
#' Call once near the top of every script. Creates or updates an entry in
#' `_tinytrail.yaml` and sets the script name so that outputs can be recorded.
#'
#' By default (`auto = TRUE`) common write functions (`write.csv`, `saveRDS`,
#' `readr::write_csv`, `ggplot2::ggsave`, etc.) are hooked automatically so
#' their output file paths are captured without any `tinytrail_write()` wrapper.
#' Set `auto = FALSE` to use explicit `tinytrail_write()` calls instead.
#'
#' @param description Character. Description of what the script does.
#' @param data_source Character. Optional. Enter the sources of data used in
#'   this script — name the dataset or survey, not a file path
#'   (e.g. `"Current Population Survey (BLS)"`).
#' @param pin_to_top Logical. Pin this script to the top of the trail. Useful
#'   for a `main.R` that sources other scripts — keeps it visible at the top of
#'   `_tinytrail.yaml` regardless of alphabetical order. Default `FALSE`.
#' @param record_runtime Logical. Record how long the script takes to run, in
#'   minutes, as `script_runtime` in `_tinytrail.yaml`. Default `TRUE`. Only
#'   some ways of running a script can be timed; see the *Runtime tracking*
#'   section below.
#' @param name Character. Override the auto-detected script name. Intended for
#'   use in tests and non-standard execution environments where auto-detection
#'   is unavailable.
#' @param auto Logical. Automatically intercept common write functions and
#'   record their output paths. Default `TRUE`. Set to `FALSE` to use explicit
#'   `tinytrail_write()` calls instead.
#' @param extra_hooks A `list` with elements `fn` and `arg` specifying
#'   additional write functions to intercept when `auto = TRUE`. `fn` is a
#'   character vector of function names (`"my_save"` for a script-level
#'   function, or `"pkg::fn"` for a package function). `arg` is a character
#'   vector of the corresponding file-path argument names. Functions from
#'   packages that are not installed are silently skipped.
#'
#' @section Runtime tracking:
#' Some scripts take minutes or hours to run, and a project often has several
#' of them that are rerun many times, for example a `main.R` that sources a
#' cleaning script, a modelling script and a report. With
#' `record_runtime = TRUE`, each script's entry in `_tinytrail.yaml` gets a
#' `script_runtime` field, such as `script_runtime: 12.4 min`, so you can see
#' at a glance which steps are slow and how long a full rerun will take.
#'
#' The time is wall-clock time from the `tinytrail()` call until the script
#' finishes, so place `tinytrail()` at the very top of the script, before
#' `library()` calls. Each run replaces the previous value. When the time is
#' recorded, a line such as `clean.R: 12.4 min elapsed` is printed.
#'
#' Whether the time can be recorded depends on how the script is run, because
#' tinytrail needs to know when the script has finished:
#'
#' | How the script is run | Time recorded? |
#' |---|---|
#' | `source("scripts/clean.R")`, also when called from another script such as `main.R` | Yes, when `source()` returns |
#' | RStudio **Source** button (Ctrl+Shift+S) or **Source with Echo** (Ctrl+Shift+Enter) | Yes, these call `source()` |
#' | `Rscript scripts/clean.R` or `R CMD BATCH`, for example from a scheduled task | Yes, when R exits |
#' | `quarto render report.qmd` (R code chunks run with knitr), or the RStudio **Render** button | Yes, when the document has finished |
#' | `rmarkdown::render()`, `knitr::knit()`, or the RStudio **Knit** button | Yes, when the document has finished |
#' | RStudio **Run All** (Ctrl+Alt+R), **Run** / Ctrl+Enter on selected lines, or running chunks one by one in a `.qmd` or `.Rmd` | No |
#'
#' Running code interactively sends it to the console one line or chunk at a
#' time, so R cannot tell when "the script" has ended, and the time would
#' include any pauses between chunks. In that case no message is printed and
#' `script_runtime` is left out of the entry for that run. To get a time,
#' run the whole file with `source()`, the **Source** button, `Rscript` or a
#' render instead.
#'
#' If a script stops with an error, the time up to the error is recorded when
#' it is run with `source()` or `Rscript`; a render that fails records no time.
#'
#' When `main.R` sources several scripts that each call `tinytrail()`, every
#' script gets its own `script_runtime`, and `main.R` gets the total.
#'
#' @returns `name` (the script name), invisibly. Called for its side effect of
#'   creating or updating the YAML trail file in the project root.
#' @seealso [tinytrail_write()] to record output paths explicitly,
#'   [tinytrail_dict()] to capture a data dictionary.
#' @export
#'
#' @examples
#' \donttest{
#' withr::with_tempdir({
#'   writeLines("Package: testproject\nVersion: 0.1.0", "DESCRIPTION")
#'
#'   tinytrail(
#'     description    = "Clean and summarise survey data",
#'     data_source    = "Current Population Survey (BLS)",
#'     record_runtime = FALSE,
#'     name           = "clean.R"
#'   )
#'   write.csv(mtcars, "clean.csv")
#'   png("age_dist.png"); hist(mtcars$mpg, main = "MPG"); dev.off()
#' })
#' }
tinytrail <- function(description,
                      data_source  = NULL,
                      pin_to_top   = FALSE,
                      record_runtime = TRUE,
                      name         = NULL,
                      auto         = TRUE,
                      extra_hooks  = NULL) {
  name <- name %||% .get_current_script_name()
  if (is.null(name)) {
    message("tinytrail: could not detect script name; run via source()")
    return(invisible(NULL))
  }

  registry_path <- file.path(.find_root(), .REGISTRY_FILENAME)
  options(.tinytrail_registry_path = registry_path)

  registry <- .read_or_init_registry(registry_path)
  now      <- format(Sys.time(), "%Y-%m-%d %H:%M")
  entry    <- .build_script_entry(
    description = description,
    data_source = data_source,
    pin_to_top  = pin_to_top,
    first_run   = registry$scripts[[name]]$first_run,
    now         = now
  )
  registry$scripts[[name]]         <- entry
  registry$data_dictionary[[name]] <- NULL

  if (sample(.TIP_FREQUENCY, 1L) == 1L) {
    message(
      "tinytrail tip: place tinytrail() at the very top of '", name, "' ",
      "(before library() calls) so the runtime covers the full script, not just the code after it."
    )
  }

  registry$scripts <- .sort_scripts(registry$scripts)
  .write_registry(registry, registry_path)

  options(.tinytrail_current_script = name)

  if (record_runtime) {
    start_sec  <- as.numeric(Sys.time())
    source_idx <- .source_frame_idx()
    .setup_runtime_hook(
      script_name   = name,
      registry_path = registry_path,
      start_sec     = start_sec,
      source_idx    = source_idx
    )
  }

  if (auto) {
    .setup_write_hooks(extra = extra_hooks)
    source_idx <- .source_frame_idx()
    if (length(source_idx) > 0L) {
      teardown_ <- .teardown_write_hooks
      do.call(
        on.exit,
        list(bquote((.(teardown_))()), add = TRUE, after = TRUE),
        envir = sys.frame(source_idx[length(source_idx)])
      )
    }
    # Rscript / interactive: hooks stay active until R exits — no teardown needed
  }

  invisible(name)
}

#' Record an output file path in the trail
#'
#' Wraps the file path argument of any save call. Registers the path under the
#' current script's trail entry and returns the path unchanged, so it can be
#' dropped inline into any save function.
#'
#' Requires `tinytrail()` to have been called first in the same session.
#'
#' @param file Character. Path to the output file.
#'
#' @return `file`, invisibly.
#' @seealso [tinytrail()] to initialise the trail, [tinytrail_dict()] to
#'   capture a data dictionary.
#' @export
#'
#' @examples
#' \donttest{
#' withr::with_tempdir({
#'   writeLines("Package: testproject\nVersion: 0.1.0", "DESCRIPTION")
#'
#'   tinytrail("Process raw data", name = "analysis.R", record_runtime = FALSE,
#'             auto = FALSE)
#'   write.csv(mtcars, tinytrail_write("clean.csv"))
#'   saveRDS(lm(mpg ~ wt, mtcars), tinytrail_write("model.rds"))
#' })
#' }
tinytrail_write <- function(file) {
  script_name <- getOption(".tinytrail_current_script")

  if (is.null(script_name)) {
    .warn_no_tinytrail(
      script_name   = .get_current_script_name() %||% "<unknown script>",
      registry_path = .registry_path()
    )
    return(invisible(file))
  }

  tryCatch({
    registry_path <- .registry_path()
    if (!file.exists(registry_path)) return(invisible(file))

    root     <- .find_root()
    rel_file <- if (startsWith(file, root)) substring(file, nchar(root) + 2L) else file

    registry     <- yaml::read_yaml(registry_path)
    existing_raw <- registry$scripts[[script_name]]$outputs %||% list()
    existing <- if (identical(existing_raw, "none") || length(existing_raw) == 0) {
      character(0)
    } else {
      as.character(unlist(existing_raw))
    }

    all_out <- unique(c(existing, rel_file))
    outputs <- all_out[order(dirname(all_out),
                             startsWith(basename(all_out), .SENSITIVITY_PREFIX),
                             basename(all_out))]

    registry$scripts[[script_name]]$outputs <- outputs
    registry$scripts[[script_name]]$n_outputs <- length(outputs)
    registry$scripts <- lapply(registry$scripts, .order_registry_entry)
    .write_registry(registry, registry_path)
  }, error = function(e) {
    message("tinytrail: could not record '", basename(file), "': ", conditionMessage(e))
  })

  invisible(file)
}

#' Add a data frame to the project data dictionary
#'
#' Place at the end of a read/clean pipeline to capture column names and
#' optionally sample values. Returns the data frame unchanged.
#'
#' Requires `tinytrail()` to have been called first in the same session.
#'
#' @param df A data frame.
#' @param df_name Character. Label for this entry in the data dictionary.
#'   Defaults to the variable name of `df` as written in the calling code
#'   (e.g. `mtcars |> tinytrail_dict()` records as `"mtcars"`). Override when
#'   the expression is not a simple name or when you need a custom label.
#' @param sample_values Logical. Record 5 sample values per column. Default `TRUE`.
#' @param sample_string_length Integer or `Inf`. Maximum characters per sample value
#'   before truncating with `"..."`. Default `18L`.
#'
#' @return `df`, invisibly.
#' @seealso [tinytrail()] to initialise the trail, [tinytrail_write()] to
#'   record output paths explicitly.
#' @export
#'
#' @examples
#' \donttest{
#' withr::with_tempdir({
#'   writeLines("Package: testproject\nVersion: 0.1.0", "DESCRIPTION")
#'
#'   tinytrail("Analyse data", name = "analysis.R", record_runtime = FALSE)
#'   dat <- mtcars |> tinytrail_dict(df_name = "cars")
#' })
#' }
tinytrail_dict <- function(df, df_name = NULL, sample_values = TRUE, sample_string_length = 18L) {
  script_name <- getOption(".tinytrail_current_script")

  if (is.null(script_name)) {
    .warn_no_tinytrail(
      script_name   = .get_current_script_name() %||% "<unknown script>",
      registry_path = .registry_path()
    )
    return(invisible(df))
  }

  if (!is.data.frame(df)) stop("tinytrail_dict() requires a data frame.")

  registry_path <- .registry_path()
  if (!file.exists(registry_path)) return(invisible(df))

  registry <- yaml::read_yaml(registry_path)
  if (is.null(registry$data_dictionary))
    registry$data_dictionary <- list()
  if (is.null(registry$data_dictionary[[script_name]]))
    registry$data_dictionary[[script_name]] <- list()

  auto_name <- deparse(substitute(df))
  dict_name <- if (!is.null(df_name)) {
    df_name
  } else if (grepl("^[A-Za-z._][A-Za-z0-9._]*$", auto_name)) {
    auto_name
  } else {
    n <- length(registry$data_dictionary[[script_name]])
    paste0("input_", n + 1L)
  }

  if (!is.null(registry$data_dictionary[[script_name]][[dict_name]])) {
    warning(
      "tinytrail_dict(): '", dict_name, "' already recorded for '", script_name,
      "' -- overwriting. Rename the data frame or use df_name to distinguish stages.",
      call. = FALSE
    )
  }

  entry <- list(
    columns = if (sample_values)
      lapply(df, \(col) lapply(as.list(col[sample(length(col), min(.DICT_SAMPLE_N, length(col)))]),
                               \(v) .truncate_sample_value(v, sample_string_length)))
    else
      as.list(names(df))
  )

  registry$data_dictionary[[script_name]][[dict_name]] <- entry
  .write_registry(registry, registry_path)

  invisible(df)
}
