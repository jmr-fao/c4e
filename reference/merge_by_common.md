# Merge Data Frames or Lists by Common Variable(s)

This function merges two data frames or lists by their common
variable(s). It uses `find_merge_var` to identify the shared columns
between the two inputs and performs a full join using
[`dplyr::full_join`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

## Usage

``` r
merge_by_common(x, y = NULL)
```

## Arguments

- x:

  A data frame, or a list of data frames.

- y:

  A data frame (optional). If provided, the function will merge `x` and
  `y` by the common column(s). If `y` is `NULL` and `x` is a list, the
  elements of `x` are merged in order, each on the columns it shares
  with the result so far.

## Value

A single data frame, the full join of the inputs.

## See also

[`full_join`](https://dplyr.tidyverse.org/reference/mutate-joins.html),
`find_merge_var()`

## Examples

``` r
# Example 1: Merging two data frames with a common column
df1 <- data.frame(ID = 1:3, Value = c(10, 20, 30))
df2 <- data.frame(ID = c(2, 3, 4), Value = c(200, 300, 400))
merged_df <- merge_by_common(df1, df2)

# Example 2: Merging a list of data frames by common columns
list_df <- list(
    data.frame(ID = 1:3, Value = c(10, 20, 30)),
    data.frame(ID = c(2, 3, 4), Value = c(200, 300, 400))
)
merged_list <- merge_by_common(list_df)
```
