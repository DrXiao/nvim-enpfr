local output = require("enpfr.output")

local function fresh_source()
  vim.cmd("silent! only")
  vim.cmd("enew")
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "Original text." })
  vim.bo[buffer].filetype = "text"
  return vim.api.nvim_get_current_win(), buffer
end

test("opens a read-only scratch buffer to the right and keeps source focus", function()
  local source_window, source_buffer = fresh_source()

  local result = output.open(source_window, vim.bo[source_buffer].filetype)

  eq(2, #vim.api.nvim_tabpage_list_wins(0))
  eq(source_window, vim.api.nvim_get_current_win())
  assert(vim.api.nvim_win_get_position(result.window)[2]
    > vim.api.nvim_win_get_position(source_window)[2])
  eq("nofile", vim.bo[result.buffer].buftype)
  eq(false, vim.bo[result.buffer].modifiable)
  eq(true, vim.bo[result.buffer].readonly)
  eq("text", vim.bo[result.buffer].filetype)
end)

test("updates only the output buffer and leaves it read-only", function()
  local source_window, source_buffer = fresh_source()
  local result = output.open(source_window, "text")

  output.set_text(result.buffer, "Revised\ntext.")

  eq({ "Original text." }, vim.api.nvim_buf_get_lines(source_buffer, 0, -1, false))
  eq({ "Revised", "text." }, vim.api.nvim_buf_get_lines(result.buffer, 0, -1, false))
  eq(false, vim.bo[result.buffer].modifiable)
  eq(true, vim.bo[result.buffer].readonly)
end)

test("reuses the output window for subsequent requests", function()
  local source_window = fresh_source()
  local first = output.open(source_window, "text")
  local second = output.open(source_window, "markdown")

  eq(first.window, second.window)
  eq(first.buffer, second.buffer)
  eq(2, #vim.api.nvim_tabpage_list_wins(0))
  eq("markdown", vim.bo[second.buffer].filetype)
end)

test("marks the buffer read-only and non-modifiable before assigning filetype", function()
  local source_window = fresh_source()

  local recorded
  local group = vim.api.nvim_create_augroup("enpfr_output_spec_filetype", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(args)
      if vim.api.nvim_buf_get_name(args.buf):match("%[English Polish") then
        recorded = {
          modifiable = vim.bo[args.buf].modifiable,
          buftype = vim.bo[args.buf].buftype,
        }
      end
    end,
  })

  local ok, err = pcall(output.open, source_window, "lua")
  vim.api.nvim_del_augroup_by_id(group)
  assert(ok, err)

  assert(recorded, "FileType autocmd did not fire for the output buffer")
  eq(false, recorded.modifiable)
  eq("nofile", recorded.buftype)
end)

test("restores read-only state even if a FileType autocmd re-enables modifiable", function()
  local source_window = fresh_source()

  local group = vim.api.nvim_create_augroup("enpfr_output_spec_ftplugin", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(args)
      if vim.api.nvim_buf_get_name(args.buf):match("%[English Polish") then
        -- Simulates a misbehaving ftplugin/autocmd that assumes any buffer
        -- receiving a FileType event is a normal editable file.
        vim.bo[args.buf].modifiable = true
        vim.bo[args.buf].readonly = false
      end
    end,
  })

  local ok, err = pcall(function()
    local result = output.open(source_window, "lua")
    eq(false, vim.bo[result.buffer].modifiable)
    eq(true, vim.bo[result.buffer].readonly)
  end)
  vim.api.nvim_del_augroup_by_id(group)
  assert(ok, err)
end)

test("opens without hanging when the source buffer has a file name", function()
  -- Regression: available_name() probed the buffer list with vim.fn.bufnr(),
  -- which treats "[English Polish]" as a character-class pattern. Any buffer
  -- with a real path matched it, so the retry loop spun forever and froze
  -- Neovim. Every other test here uses :enew, whose unnamed buffer is the one
  -- case the pattern never matched.
  vim.cmd("silent! only")
  local path = vim.fn.tempname() .. ".txt"
  vim.fn.writefile({ "Original text." }, path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  local source_window = vim.api.nvim_get_current_win()

  local result = output.open(source_window, "text")

  eq(2, #vim.api.nvim_tabpage_list_wins(0))
  assert(vim.api.nvim_buf_is_valid(result.buffer))
  eq("[English Polish]", vim.fn.fnamemodify(vim.api.nvim_buf_get_name(result.buffer), ":t"))

  vim.cmd("silent! only")
  vim.fn.delete(path)
end)

test("falls back to the next number when the base name is taken", function()
  local source_window = fresh_source()
  local taken = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(taken, "[English Polish]")

  local result = output.open(source_window, "text")

  -- Compare the tail only: nvim_buf_set_name() stores the name with the cwd
  -- prepended, so the full name is not the literal string that was assigned.
  eq("[English Polish 2]", vim.fn.fnamemodify(vim.api.nvim_buf_get_name(result.buffer), ":t"))

  vim.cmd("silent! only")
  vim.api.nvim_buf_delete(taken, { force = true })
end)
