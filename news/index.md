# Changelog

## tinytrail (development version)

- New
  [`tinytrail_the_end()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_the_end.md):
  put it at the end of a script to record the time since
  [`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
  as `script_runtime`.

- [`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
  no longer tries to detect when a script ends, so it no longer prints
  “runtime tracking requires source() …”. The `record_runtime` argument
  is deprecated and ignored.

- Rendering with Quarto (`report.rmarkdown`) or rendering a plain script
  (`script.spin.Rmd`) now records the source file name (`report.qmd`,
  `script.R`), so a render and an interactive run update the same entry
  instead of creating duplicates.

## tinytrail 0.1.0

CRAN release: 2026-07-04

- Initial release (renamed from `tinylog`).
- [`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
  registers a script in the project YAML trail and optionally records
  elapsed runtime.
- [`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
  wraps any save call to log the output file path under the calling
  script’s trail entry.
- [`tinytrail_dict()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_dict.md)
  captures column names and sample values for input data frames.
