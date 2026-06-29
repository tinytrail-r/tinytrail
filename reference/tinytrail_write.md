# Record an output file path in the trail

Wraps the file path argument of any save call. Registers the path under
the current script's trail entry and returns the path unchanged, so it
can be dropped inline into any save function.

## Usage

``` r
tinytrail_write(file)
```

## Arguments

- file:

  Character. Path to the output file.

## Value

`file`, invisibly.

## Details

Requires
[`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
to have been called first in the same session.

## See also

[`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
to initialise the trail,
[`tinytrail_dict()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_dict.md)
to capture a data dictionary.

## Examples

``` r
# \donttest{
withr::with_tempdir({
  writeLines("Package: testproject\nVersion: 0.1.0", "DESCRIPTION")

  tinytrail("Process raw data", name = "analysis.R", record_runtime = FALSE,
            auto = FALSE)
  write.csv(mtcars, tinytrail_write("clean.csv"))
  saveRDS(lm(mpg ~ wt, mtcars), tinytrail_write("model.rds"))
})
# }
```
