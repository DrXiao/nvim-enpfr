local diff = require("enpfr.diff")

test("reports no changes for identical text", function()
  local ranges = diff.changed_ranges("Hello world.", "Hello world.")

  eq({}, ranges)
end)

test("flags a single substituted word", function()
  local ranges = diff.changed_ranges("Hello world.", "Hello there.")

  eq({ { row = 0, start_col = 6, end_col = 12 } }, ranges)
end)

test("flags multiple substituted words independently", function()
  local ranges = diff.changed_ranges("The quick fox jumps.", "The slow fox leaps.")

  eq({
    { row = 0, start_col = 4, end_col = 8 },
    { row = 0, start_col = 13, end_col = 19 },
  }, ranges)
end)

test("flags an inserted word not present in the original", function()
  local ranges = diff.changed_ranges("Hello world.", "Hello there world.")

  eq({ { row = 0, start_col = 6, end_col = 11 } }, ranges)
end)

test("flags only the word that breaks the common subsequence when reordered", function()
  local ranges = diff.changed_ranges("one two three", "three one two")

  -- "one two" survives as a common subsequence of both word lists, so only
  -- "three" (now out of order relative to it) is flagged.
  eq({ { row = 0, start_col = 0, end_col = 5 } }, ranges)
end)

test("reports row-aware ranges across multiple lines", function()
  local ranges = diff.changed_ranges("first line\nsecond line", "first line\nsecond row")

  eq({ { row = 1, start_col = 7, end_col = 10 } }, ranges)
end)

test("returns no ranges for empty original and empty text", function()
  eq({}, diff.changed_ranges("", ""))
end)
