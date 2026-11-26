# tinytrail (development version)

* `tinytrail()` no longer prints "runtime tracking requires source() ..." when a script is run line by line or chunk by chunk. The new *Runtime tracking* section in `?tinytrail` explains which ways of running a script record `script_runtime` and which don't.
* Runtime is now also recorded when a script is run with `Rscript` or `R CMD BATCH`.

# tinytrail 0.1.0

* Initial release (renamed from `tinylog`).
* `tinytrail()` registers a script in the project YAML trail and optionally records elapsed runtime.
* `tinytrail_write()` wraps any save call to log the output file path under the calling script's trail entry.
* `tinytrail_dict()` captures column names and sample values for input data frames.
