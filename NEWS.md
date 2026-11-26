# tinytrail (development version)

* New `tinytrail_the_end()`: put it at the end of a script to record the time since `tinytrail()`. The time is stored as `runtime_render` (Quarto/R Markdown render), `runtime_interactive` (Run All, line by line) or `runtime_script` (`source()`, `Rscript`); each run only updates its own field. This replaces the old `script_runtime` field.
* `tinytrail()` no longer tries to detect when a script ends, so it no longer prints "runtime tracking requires source() ...". The `record_runtime` argument is deprecated and ignored.

* Rendering with Quarto (`report.rmarkdown`) or rendering a plain script (`script.spin.Rmd`) now records the source file name (`report.qmd`, `script.R`), so a render and an interactive run update the same entry instead of creating duplicates.

# tinytrail 0.1.0

* Initial release (renamed from `tinylog`).
* `tinytrail()` registers a script in the project YAML trail and optionally records elapsed runtime.
* `tinytrail_write()` wraps any save call to log the output file path under the calling script's trail entry.
* `tinytrail_dict()` captures column names and sample values for input data frames.
