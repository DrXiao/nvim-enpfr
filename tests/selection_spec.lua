local selection = require("enpfr.selection")

test("extracts an inclusive characterwise selection", function()
  local lines = { "prefix first", "second suffix" }

  local result = selection.extract(lines, "v", { 1, 7 }, { 2, 5 })

  eq("first\nsecond", result)
end)

test("normalizes a reversed characterwise selection", function()
  local lines = { "prefix first", "second suffix" }

  local result = selection.extract(lines, "v", { 2, 5 }, { 1, 7 })

  eq("first\nsecond", result)
end)

test("does not split a multibyte final character", function()
  local lines = { "Fix café." }

  local result = selection.extract(lines, "v", { 1, 4 }, { 1, 7 })

  eq("café", result)
end)

test("extracts complete lines from a linewise selection", function()
  local lines = { "one", "two", "three" }

  local result = selection.extract(lines, "V", { 1, 2 }, { 2, 0 })

  eq("one\ntwo", result)
end)

test("extracts each row from a blockwise selection", function()
  local lines = { "abcde", "12345", "vwxyz" }

  local result = selection.extract(lines, "\22", { 1, 1 }, { 3, 3 })

  eq("bcd\n234\nwxy", result)
end)

test("uses virtual columns for blockwise selections containing tabs", function()
  vim.cmd("enew!")
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].tabstop = 8
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "a\tX", "abcdefghij" })

  local result = selection.from_buffer(buffer, "\22", { 1, 1 }, { 2, 7 })

  eq("\t\nbcdefgh", result)
end)

test("keeps wide characters intact at blockwise boundaries", function()
  vim.cmd("enew!")
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "a界XQ", "abcdefgh" })

  local result = selection.from_buffer(buffer, "\22", { 1, 1 }, { 2, 3 })

  eq("界X\nbcd", result)
end)

test("adjusts forward exclusive selections to omit the cursor endpoint", function()
  local first, last = selection.adjust_exclusive(
    { "abcdef" },
    { 1, 1 },
    { 1, 4 },
    { 1, 4 }
  )

  eq({ 1, 1 }, first)
  eq({ 1, 3 }, last)
end)

test("exclusive selections omit the upper endpoint when reversed", function()
  local first, last = selection.adjust_exclusive(
    { "abcdef" },
    { 1, 1 },
    { 1, 4 },
    { 1, 1 }
  )

  eq({ 1, 1 }, first)
  eq({ 1, 3 }, last)
end)
