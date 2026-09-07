local float_ui = require("enpfr.float_ui")

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

test("select opens a centered floating window listing every item", function()
  vim.cmd("silent! only")
  local before = vim.api.nvim_get_current_win()

  float_ui.select({ "a", "b", "c" }, { prompt = "Pick" }, function() end)

  local window = vim.api.nvim_get_current_win()
  assert(window ~= before, "select did not focus a new window")
  local config = vim.api.nvim_win_get_config(window)
  eq("editor", config.relative)
  eq({ "a", "b", "c" }, vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false))

  feed("q")
end)

test("select confirms the item under the cursor with <CR>", function()
  vim.cmd("silent! only")
  local result

  float_ui.select({ "a", "b", "c" }, { prompt = "Pick" }, function(choice, index)
    result = { choice, index }
  end)
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 2, 0 })
  feed("<CR>")

  eq({ "b", 2 }, result)
  eq(false, vim.api.nvim_win_is_valid(window))
end)

test("select cancels with q and returns nil", function()
  vim.cmd("silent! only")
  local result = "not called"

  float_ui.select({ "a", "b" }, {}, function(choice)
    result = choice
  end)
  local window = vim.api.nvim_get_current_win()
  feed("q")

  eq(nil, result)
  eq(false, vim.api.nvim_win_is_valid(window))
end)

test("select cancels with <Esc> and returns nil", function()
  vim.cmd("silent! only")
  local result = "not called"

  float_ui.select({ "a", "b" }, {}, function(choice)
    result = choice
  end)
  feed("<Esc>")

  eq(nil, result)
end)

test("select invokes the callback with nil for an empty item list", function()
  vim.cmd("silent! only")
  local before = vim.api.nvim_get_current_win()
  local result = "not called"

  float_ui.select({}, {}, function(choice)
    result = choice
  end)
  vim.wait(200, function()
    return result == nil
  end)

  eq(nil, result)
  eq(before, vim.api.nvim_get_current_win())
end)

test("input opens a floating window in insert mode and confirms typed text", function()
  vim.cmd("silent! only")
  local result

  float_ui.input({ prompt = "Model" }, function(value)
    result = value
  end)
  local window = vim.api.nvim_get_current_win()
  feed("opus<CR>")

  eq("opus", result)
  eq(false, vim.api.nvim_win_is_valid(window))
end)

test("input pre-fills the default value", function()
  vim.cmd("silent! only")
  local result

  float_ui.input({ prompt = "Model", default = "sonnet" }, function(value)
    result = value
  end)
  local window = vim.api.nvim_get_current_win()
  eq({ "sonnet" }, vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false))
  feed("<Esc>")

  eq(nil, result)
end)

test("input cancels with <Esc> and returns nil", function()
  vim.cmd("silent! only")
  local result = "not called"

  float_ui.input({ prompt = "Model" }, function(value)
    result = value
  end)
  feed("x<Esc>")

  eq(nil, result)
end)

test("input treats a blank line as cancelled", function()
  vim.cmd("silent! only")
  local result = "not called"

  float_ui.input({ prompt = "Model" }, function(value)
    result = value
  end)
  feed("<CR>")

  eq(nil, result)
end)
