# tinytrail 0.2.0

## New features

* New `tinytrail_the_end()`: put it at the end of a script to record the time since `tinytrail()` as `script_runtime` (#12).

## Deprecations

* The `record_runtime` argument of `tinytrail()` is deprecated and ignored (it gives a warning if set). `tinytrail()` no longer tries to detect when a script ends, so it no longer prints "runtime tracking requires source() ..." (#12).

## Bug fixes

* `tinytrail_write()` and the automatic hooks now record outputs written from inside anonymous functions, `lapply()`/`vapply()` and Quarto chunks, instead of failing with "values must be length 1" (#9).
* Automatic recording now only records files saved by the user's own code. Writes made by RStudio, knitr, rmarkdown, evaluate and Quarto (chunk figures, cache, plot previews) and files in R's session temp folder are skipped (#9).
* Rendering with Quarto (`report.rmarkdown`) or rendering a plain script (`script.spin.Rmd`) now records the source file name (`report.qmd`, `script.R`), so a render and an interactive run update the same entry instead of creating duplicates (#13).

# tinytrail 0.1.0

* Initial release (renamed from `tinylog`).
* `tinytrail()` registers a script in the project YAML trail and optionally records elapsed runtime.
* `tinytrail_write()` wraps any save call to log the output file path under the calling script's trail entry.
* `tinytrail_dict()` captures column names and sample values for input data frames.
