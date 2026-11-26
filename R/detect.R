# Context detection: where and how is the current script running?

# Frame numbers of active source() calls on the call stack.
# Matches the function part of each call structurally (`source`, `base::source`
# or `base:::source`). deparse() is avoided on purpose: it returns several
# strings for multiline function expressions (e.g. anonymous functions), which
# broke vapply(..., logical(1)) -- see issue #9.
.source_frame_idx <- function() {
  is_source <- function(call) {
    fn <- call[[1L]]
    if (is.symbol(fn)) return(identical(fn, quote(source)))
    is.call(fn) && length(fn) == 3L &&
      (identical(fn[[1L]], quote(`::`)) || identical(fn[[1L]], quote(`:::`))) &&
      identical(fn[[2L]], quote(base)) && identical(fn[[3L]], quote(source))
  }
  which(vapply(sys.calls(), is_source, logical(1)))
}

.script_dir <- function() {
  idx <- .source_frame_idx()
  if (length(idx) > 0) {
    frame <- sys.frame(idx[length(idx)])
    path  <- if (is.character(frame$ofile)) frame$ofile
              else if (is.character(frame$file)) frame$file
              else NULL
    if (!is.null(path) && nzchar(path))
      return(dirname(normalizePath(path, mustWork = FALSE)))
  }
  if (requireNamespace("knitr", quietly = TRUE)) {
    input <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NULL)
    if (is.character(input) && nzchar(input))
      return(dirname(normalizePath(input, mustWork = FALSE)))
  }
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    path <- sub("^--file=", "", file_arg[[1L]])
    return(dirname(normalizePath(path, mustWork = FALSE)))
  }
  NULL
}

.in_knitr <- function() {
  requireNamespace("knitr", quietly = TRUE) &&
    !is.null(tryCatch(knitr::current_input(), error = function(e) NULL))
}

.get_current_script_name <- function() {
  # 1. source() call stack -- standard usage
  idx <- .source_frame_idx()
  if (length(idx) > 0) {
    frame <- sys.frame(idx[length(idx)])
    path  <- if (is.character(frame$ofile)) frame$ofile
              else if (is.character(frame$file)) frame$file
              else NULL
    if (!is.null(path) && nzchar(path)) return(basename(path))
  }
  # 2. knitr / Quarto rendering
  if (requireNamespace("knitr", quietly = TRUE)) {
    input <- tryCatch(knitr::current_input(), error = function(e) NULL)
    if (is.character(input) && nzchar(input)) return(basename(input))
  }
  # 3. Rscript path/to/script.R
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(basename(sub("^--file=", "", file_arg[[1L]])))
  # 4. RStudio interactive fallback
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    path <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) NULL)
    if (is.character(path) && nzchar(path)) return(basename(path))
  }
  NULL
}
