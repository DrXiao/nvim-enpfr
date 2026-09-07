local M = {}

local function centered_geometry(width, height, title)
  width = math.max(1, math.min(width, vim.o.columns - 4))
  height = math.max(1, math.min(height, vim.o.lines - 4))
  local geometry = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  }
  if title and title ~= "" then
    geometry.title = " " .. title .. " "
    geometry.title_pos = "center"
  end
  return geometry
end

local function scratch_buffer()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  return buffer
end

-- Centered floating-window replacement for vim.ui.select: j/k or the arrow
-- keys move the cursorline (ordinary normal-mode movement, nothing to wire
-- up), <CR> confirms the line under the cursor, q/<Esc>/leaving the window
-- cancels. Callback shape matches vim.ui.select: on_choice(item, index) or
-- on_choice(nil) if cancelled.
function M.select(items, opts, on_choice)
  opts = opts or {}
  if #items == 0 then
    vim.schedule(function()
      on_choice(nil)
    end)
    return
  end

  local format_item = opts.format_item or tostring
  local labels = {}
  local width = #(opts.prompt or "")
  for index, item in ipairs(items) do
    labels[index] = format_item(item)
    width = math.max(width, #labels[index])
  end

  local buffer = scratch_buffer()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, labels)
  vim.bo[buffer].modifiable = false

  local window = vim.api.nvim_open_win(buffer, true, centered_geometry(width + 2, #labels, opts.prompt))
  vim.wo[window].cursorline = true

  local finished = false
  local function finish(choice, index)
    if finished then
      return
    end
    finished = true
    if vim.api.nvim_win_is_valid(window) then
      vim.api.nvim_win_close(window, true)
    end
    on_choice(choice, index)
  end

  local keymap_opts = { buffer = buffer, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", function()
    local index = vim.api.nvim_win_get_cursor(window)[1]
    finish(items[index], index)
  end, keymap_opts)
  vim.keymap.set("n", "<2-LeftMouse>", function()
    local index = vim.api.nvim_win_get_cursor(window)[1]
    finish(items[index], index)
  end, keymap_opts)
  vim.keymap.set("n", "q", function()
    finish(nil, nil)
  end, keymap_opts)
  vim.keymap.set("n", "<Esc>", function()
    finish(nil, nil)
  end, keymap_opts)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buffer,
    once = true,
    callback = function()
      finish(nil, nil)
    end,
  })
end

-- Centered floating single-line replacement for vim.ui.input. <CR> confirms
-- the line's text (empty counts as cancelled, matching vim.ui.input()'s
-- convention of nil-on-cancel), <Esc>/leaving the window cancels.
function M.input(opts, on_confirm)
  opts = opts or {}
  local buffer = scratch_buffer()
  if opts.default and opts.default ~= "" then
    vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { opts.default })
  end

  local width = math.max(30, #(opts.prompt or "") + 10)
  local window = vim.api.nvim_open_win(buffer, true, centered_geometry(width, 1, opts.prompt))
  -- Enter insert mode (append-at-end, like startinsert!) by feeding the key
  -- directly rather than via the :startinsert command: :startinsert only
  -- takes effect on Neovim's next main-loop tick, which never arrives in a
  -- headless `-l script.lua` run, leaving the window stuck in Normal mode.
  vim.api.nvim_feedkeys("A", "n", false)

  local finished = false
  local function finish(value)
    if finished then
      return
    end
    finished = true
    if vim.api.nvim_win_is_valid(window) then
      vim.api.nvim_win_close(window, true)
    end
    on_confirm(value)
  end

  local function confirm()
    local line = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] or ""
    finish(line ~= "" and line or nil)
  end

  local function cancel()
    finish(nil)
  end

  local keymap_opts = { buffer = buffer, nowait = true, silent = true }
  vim.keymap.set({ "i", "n" }, "<CR>", confirm, keymap_opts)
  vim.keymap.set({ "i", "n" }, "<Esc>", cancel, keymap_opts)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buffer,
    once = true,
    callback = cancel,
  })
end

return M
