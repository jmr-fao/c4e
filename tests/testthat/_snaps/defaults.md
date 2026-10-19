# a value from upstream is used and announced

    Code
      out <- c4e_default(NULL, from = c(30, 35), arg_name = "above", field = "threshold")
    Message
      Using `above = c(30, 35)` from upstream threshold.

# a required argument with nothing upstream is an error naming it

    Code
      c4e_default(NULL, from = NULL, arg_name = "unit")
    Condition
      Error:
      ! `unit` is missing, and the input carries no unit to use instead.
      i Give `unit` explicitly, or build the input with a climatic4economist step that records it.

# an explicit value that contradicts the metadata is an error

    Code
      check_meta_agrees("K", "C", "unit", hint = "Convert the data first.")
    Condition
      Error:
      ! `unit` is `"K"`, but the input's unit is `"C"`.
      i Convert the data first.

# c4e_history() prints the pipeline as code

    Code
      print(history)
    Output
      <c4e history: 3 steps, 1 min 4 s>
      extract_by_coord(id = "ID") |>              # 0.8 s
        calc_threshold_day(above = c(30, 35)) |>  # 1.2 s
        calc_spell(min_spell = 2L)                # 1 min 2 s

# c4e_history() of a table without history is empty

    Code
      print(c4e_history(tibble::tibble(ID = "1")))
    Output
      <c4e history: no recorded steps>

