# Private helpers for automatic write-call interception (used by tinytrail()).

# Built-in write functions to intercept: key -> list(fn, pkg, arg)
# "arg" is the parameter name holding the output file path in each function.
.WRITE_HOOKS <- list(
  write.table   = list(fn = "write.table",   pkg = "utils",      arg = "file"),
  write.csv     = list(fn = "write.csv",     pkg = "utils",      arg = "file"),
  write.csv2    = list(fn = "write.csv2",    pkg = "utils",      arg = "file"),
  saveRDS       = list(fn = "saveRDS",       pkg = "base",       arg = "file"),
  save          = list(fn = "save",          pkg = "base",       arg = "file"),
  write_csv     = list(fn = "write_csv",     pkg = "readr",      arg = "file"),
  write_tsv     = list(fn = "write_tsv",     pkg = "readr",      arg = "file"),
  write_delim   = list(fn = "write_delim",   pkg = "readr",      arg = "file"),
  write_rds     = list(fn = "write_rds",     pkg = "readr",      arg = "file"),
  ggsave        = list(fn = "ggsave",        pkg = "ggplot2",    arg = "filename"),
  write_xlsx    = list(fn = "write_xlsx",    pkg = "writexl",    arg = "path"),
  saveWorkbook  = list(fn = "saveWorkbook",  pkg = "openxlsx",   arg = "file"),
  write_parquet = list(fn = "write_parquet", pkg = "arrow",      arg = "sink"),
  write_feather = list(fn = "write_feather", pkg = "arrow",      arg = "sink"),
  write_sav     = list(fn = "write_sav",     pkg = "haven",      arg = "path"),
  write_dta     = list(fn = "write_dta",     pkg = "haven",      arg = "path"),
  write_sas     = list(fn = "write_sas",     pkg = "haven",      arg = "path"),
  write_json    = list(fn = "write_json",    pkg = "jsonlite",   arg = "path"),
  fwrite        = list(fn = "fwrite",        pkg = "data.table", arg = "file")
)

# Parses "pkg::fn" or "fn" from an extra_hooks entry into a spec list.
.parse_hook_spec <- function(entry_name, arg) {
  if (grepl("::", entry_name, fixed = TRUE)) {
    parts <- strsplit(entry_name, "::", fixed = TRUE)[[1L]]
    list(fn = parts[2L], pkg = parts[1L], arg = arg)
  } else {
    list(fn = entry_name, pkg = NULL, arg = arg)
  }
}

# Traces a single function. Returns TRUE on success, FALSE if unavailable.
.hook_one <- function(fn_name, pkg, arg) {
  ns <- if (!is.null(pkg)) {
    if (!requireNamespace(pkg, quietly = TRUE)) return(FALSE)
    asNamespace(pkg)
  } else {
    globalenv()
  }

  tracer <- bquote(
    tryCatch({
      if (!is.null(getOption(".tinytrail_current_script"))) {
        val <- .(as.name(arg))
        if (is.character(val) && length(val) == 1L && nzchar(val))
          tinytrail_write(val)
      }
    }, error = function(e) NULL)
  )

  tryCatch(
    { suppressMessages(trace(fn_name, tracer = tracer, print = FALSE, where = ns)); TRUE },
    error = function(e) FALSE
  )
}

# Activates hooks for all built-in write functions plus any user-supplied extras.
# Stores the active key list and full hook table in options for teardown.
.setup_write_hooks <- function(extra = NULL) {
  hooks <- .WRITE_HOOKS
  if (!is.null(extra)) {
    parsed <- Map(.parse_hook_spec, names(extra), extra)
    for (spec in parsed)
      hooks[[paste0(spec$pkg %||% "global", "::", spec$fn)]] <- spec
  }

  traced <- character(0)
  for (key in names(hooks)) {
    spec <- hooks[[key]]
    if (.hook_one(spec$fn, spec$pkg, spec$arg)) traced <- c(traced, key)
  }

  options(.tinytrail_traced_fns  = traced,
          .tinytrail_hooks_table = hooks)
  invisible(traced)
}

# Removes all active hooks and clears the tracking options.
.teardown_write_hooks <- function() {
  traced <- getOption(".tinytrail_traced_fns",  character(0))
  hooks  <- getOption(".tinytrail_hooks_table", list())
  for (key in traced) {
    spec <- hooks[[key]]
    if (is.null(spec)) next
    ns <- if (!is.null(spec$pkg)) {
      tryCatch(asNamespace(spec$pkg), error = function(e) NULL)
    } else {
      globalenv()
    }
    if (!is.null(ns))
      tryCatch(suppressMessages(untrace(spec$fn, where = ns)), error = function(e) NULL)
  }
  options(.tinytrail_traced_fns  = NULL,
          .tinytrail_hooks_table = NULL)
  invisible(NULL)
}

