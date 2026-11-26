# Record the total runtime of a script

Sometimes it's nice to know the total runtime. Add `tinytrail_the_end()`
at the end of the script; it records the time between
[`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
and this marker as `script_runtime` in `_tinytrail.yaml`.

## Usage

``` r
tinytrail_the_end()
```

## Value

The runtime in minutes, invisibly.

## Details

Caveat: if you run the code line by line, the time may not be reliable,
because it then includes any pauses between lines.

## See also

[`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md)
to initialise the trail.

## Examples

``` r
# \donttest{
withr::with_tempdir({
  writeLines("Package: testproject\nVersion: 0.1.0", "DESCRIPTION")

  tinytrail("Slow analysis", name = "analysis.R")
  Sys.sleep(1)
  tinytrail_the_end()
})
#> analysis.R: 0.0 min runtime
# }
```
