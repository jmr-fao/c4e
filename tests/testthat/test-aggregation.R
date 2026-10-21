# --- filter_between --------------------------------------------------------

test_that("filter_between keeps rows inside the range, endpoints included", {
    df <- data.frame(date = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")))
    dates <- list(start_date = as.Date("2024-01-15"),
                  end_date = as.Date("2024-03-01"))

    out <- filter_between(df, dates)
    expect_equal(out$date, as.Date(c("2024-02-01", "2024-03-01")))
})

test_that("filter_between returns no rows when the range excludes everything", {
    df <- data.frame(date = as.Date(c("2024-01-01", "2024-02-01")))
    dates <- list(start_date = as.Date("2025-01-01"),
                  end_date = as.Date("2025-12-31"))

    expect_equal(nrow(filter_between(df, dates)), 0L)
})
