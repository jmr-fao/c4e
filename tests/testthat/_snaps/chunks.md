# an estimate over the budget splits by unit and gives the same result

    Code
      out <- with_chunks(toy_tbl(), fn, mem_estimate = 3.5 * 1024, label = "Window summaries",
      what = "locations")
    Message
      i Window summaries needs about 3.5 KB; the memory budget is 1.0 KB.
        Splitting 12 locations into 4 chunks.

# chunk = <n> forces n units per chunk, chunk = FALSE forbids splitting

    Code
      out <- with_chunks(toy_tbl(), fn, chunk = 5, what = "locations")
    Message
      i Computing: splitting 12 locations into 3 chunks of up to 5.

---

    Code
      with_chunks(toy_tbl(), fn, chunk = FALSE, mem_estimate = 4096, label = "Window summaries")
    Condition
      Error:
      ! Window summaries needs about 4.0 KB, more than the memory budget of 1.0 KB.
      i Allow splitting with `chunk = "auto"`, or raise the budget with `options(climatic4economist.mem_limit = ...)`.

