# tinytrail: notes for Claude

Short, durable project knowledge. Keep this file under about 60 lines:
when you add something, remove or merge something outdated. No
changelogs (NEWS.md has those) and nothing the code already says
plainly.

## Working rules

- Default branch is `master`. Never push to it; work on a branch and
  open a draft PR. Tomas reviews, tests and merges himself.
- Suggestions in issues are ideas, not specs. Find the root cause, weigh
  alternatives, and say in the PR why you chose your fix.
- Pure R package, no compiled code. Keep it that way: Tomas installs PR
  branches without Rtools, from the GitHub
  `archive/refs/heads/<branch>.tar.gz` link.
- CRAN package: keep `R CMD check` clean and keep dependencies light
  (only `yaml` in Imports).

## Design decisions

- Runtime:
  [`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
  notes the start time and
  [`tinytrail_the_end()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_the_end.md),
  placed at the end of a script, writes one `script_runtime` field. The
  latest run wins. There is no render/interactive/script label (tried
  and reverted in \#11) and no automatic end detection: hooks on
  [`source()`](https://rdrr.io/r/base/source.html), knitr or R exit were
  removed in 0.2.0. `record_runtime` is deprecated and ignored.
- Script name: a Quarto render knits a temporary `report.rmarkdown`, and
  rendering `script.R` knits `script.spin.Rmd`. Both must be recorded as
  the file the user wrote (`report.qmd`, `script.R`), so that a render
  and an interactive run share one trail entry (`.knitr_source_name()`
  in `R/detect.R`).
- Automatic output recording only records files saved by the user’s own
  code. Writes from RStudio internals and from
  knitr/rmarkdown/evaluate/quarto (chunk figures, cache, plot previews)
  and session temp files are skipped (`.called_by_tooling()` in
  `R/auto_trail.R`). Explicit
  [`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
  calls are always recorded.
- Call-stack checks must return one value per frame: compare calls
  structurally (`identical(call[[1]], quote(source))`), never with
  [`deparse()`](https://rdrr.io/r/base/deparse.html), which returns
  several strings for multiline expressions (#9).

## Known issues / open ideas

- \#7: `missing.count` option for
  [`tinytrail_dict()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_dict.md)
  (enhancement, open).
