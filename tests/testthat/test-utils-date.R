test_that("to_date normalises separators and strips the leading X", {
    expect_equal(to_date("X2023_05_01"), "2023-05-01")
    expect_equal(to_date("X2023.12.31"), "2023-12-31")
    expect_equal(to_date("2023/12/31"), "2023-12-31")
    expect_equal(to_date("2023-12-31"), "2023-12-31")
})

test_that("to_date is vectorised", {
    expect_equal(to_date(c("X2020_01_01", "X2021.02.02")),
                 c("2020-01-01", "2021-02-02"))
})

test_that("to_stata_format produces valid Stata names", {
    expect_equal(to_stata_format("2024-01-01"), "X2024_01_01")
    expect_equal(to_stata_format("var.1"), "var1")
    expect_equal(to_stata_format("123_test"), "X123_test")
})

test_that("to_stata_format leaves names that already start with a letter", {
    expect_equal(to_stata_format("temp_mean"), "temp_mean")
})

