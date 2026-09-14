local diff = require("enpfr.diff")

local M = {}
local outputs = {}

local NAME_BASE = "[English Polish]"
local MAX_NAME_ATTEMPTS = 99
local DIFF_HIGHLIGHT_GROUP = "EnPfrDiffChanged"
local diff_namespace = vim.api.nvim_create_namespace("enpfr_diff")

-- Linked to DiagnosticWarn rather than a DiffText/DiffAdd-style group:
-- those highlight the background, but a changed word here should only
-- recolor its characters so the surrounding text stays visually
-- undisturbed. DiagnosticWarn is foreground-only and, unlike Added/Changed/
-- Removed, guaranteed to exist in every Neovim version this plugin
-- supports. `default = true` only takes effect where the active
-- colorscheme hasn't already defined this group, so a user's own
-- `:highlight EnPfrDiffChanged` always wins. Colorscheme changes reset
-- highlight groups, so the default has to be reapplied on every
-- ColorScheme event to survive one.
local function define_diff_highlight()
  vim.api.nvim_set_hl(0, DIFF_HIGHLIGHT_GROUP, { link = "DiagnosticWarn", default = true })
end

define_diff_highlight()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("enpfr_diff_highlight", { clear = true }),
  callback = define_diff_highlight,
})

-- Name the buffer without ever querying the buffer list for the name first.
-- vim.fn.bufnr() treats its string argument as a Vim pattern, and "[English
-- Polish]" is a character class that matches almost every buffer name, so a
-- "is this name free?" probe never fails and any retry loop built on it never
-- terminates. Comparing against nvim_buf_get_name() is no better: it returns
-- the name with the cwd prepended, not the literal string set here.
-- nvim_buf_set_name() itself raises E95 on a duplicate, so attempting the
-- assignment is both the check and the action. The loop is bounded so no
-- pathological buffer list can freeze Neovim; an unnamed scratch buffer is a
-- harmless fallback.
local function assign_name(buffer)
  for number = 1, MAX_NAME_ATTEMPTS do
    local candidate = number == 1
      and NAME_BASE
      or ("[English Polish " .. number .. "]")
    if pcall(vim.api.nvim_buf_set_name, buffer, candidate) then
      return true
    end
  end
  return false
end

local function configure_buffer(buffer, filetype)
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].undolevels = -1
  -- Mark the buffer non-modifiable and non-editable *before* assigning
  -- filetype. Assigning filetype fires global FileType autocommands (LSP
  -- autostart, formatters, Copilot, etc.). Many such integrations check
  -- 'modifiable'/'buftype' to decide whether a buffer is a real, editable
  -- file before attaching; doing this first stops them from treating this
  -- read-only preview buffer as one.
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].readonly = true
  vim.bo[buffer].filetype = filetype
  -- Re-assert immediately after: a FileType-triggered ftplugin/autocmd could
  -- have flipped modifiable/readonly back on while treating this buffer as a
  -- normal editable file.
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].readonly = true
end

local function configure_window(window)
  vim.wo[window].wrap = true
  vim.wo[window].linebreak = true
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].cursorline = false
  vim.wo[window].signcolumn = "no"
end

function M.open(source_window, filetype)
  local tabpage = vim.api.nvim_win_get_tabpage(source_window)
  local current = outputs[tabpage]

  if current
    and vim.api.nvim_win_is_valid(current.window)
    and vim.api.nvim_buf_is_valid(current.buffer)
  then
    configure_buffer(current.buffer, filetype)
    configure_window(current.window)
    vim.api.nvim_set_current_win(source_window)
    return current
  end

  vim.api.nvim_set_current_win(source_window)
  vim.cmd("rightbelow vsplit")
  local window = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_create_buf(false, true)
  assign_name(buffer)
  vim.api.nvim_win_set_buf(window, buffer)
  configure_buffer(buffer, filetype)
  configure_window(window)

  current = { buffer = buffer, window = window }
  outputs[tabpage] = current
  vim.api.nvim_set_current_win(source_window)
  return current
end

-- `original`, when given, is the pre-polish source text: the parts of `text`
-- that differ from it (at word granularity) are recolored with
-- DIFF_HIGHLIGHT_GROUP so the user can see at a glance what the backend
-- actually changed. Omit it for status/error text, where no such comparison
-- applies.
function M.set_text(buffer, text, original)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  local lines = vim.split(text, "\n", { plain = true })
  vim.bo[buffer].readonly = false
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].readonly = true

  vim.api.nvim_buf_clear_namespace(buffer, diff_namespace, 0, -1)
  if original then
    for _, range in ipairs(diff.changed_ranges(original, text)) do
      vim.api.nvim_buf_set_extmark(buffer, diff_namespace, range.row, range.start_col, {
        end_col = range.end_col,
        hl_group = DIFF_HIGHLIGHT_GROUP,
      })
    end
  end
  return true
end

return M
