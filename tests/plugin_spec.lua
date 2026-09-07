local translator = require("enpfr")

test("registers polish and cancellation commands", function()
  translator.setup({ keymap = false })
  local commands = vim.api.nvim_get_commands({})

  assert(commands.EnPfr, "EnPfr command was not registered")
  assert(commands.EnPfrCancel, "EnPfrCancel command was not registered")
  eq("*", commands.EnPfr.nargs)
  eq(".", commands.EnPfr.range)
end)

test("binds the default <leader>enpfr visual mapping when keymap is unset", function()
  translator.setup({})
  assert(vim.fn.maparg("<leader>enpfr", "x") ~= "")

  translator.setup({ keymap = false })
end)

test("removes the previous visual mapping when disabled", function()
  translator.setup({ keymap = "<leader>enpfr" })
  assert(vim.fn.maparg("<leader>enpfr", "x") ~= "")

  translator.setup({ keymap = false })

  eq("", vim.fn.maparg("<leader>enpfr", "x"))
end)

test("registers the settings menu command", function()
  translator.setup({ keymap = false })
  local commands = vim.api.nvim_get_commands({})

  assert(commands.EnPfrConfig, "EnPfrConfig command was not registered")
end)

test("binds and unbinds a normal-mode keymap to open the settings menu", function()
  translator.setup({ keymap = false, config_keymap = "<F9>" })
  assert(vim.fn.maparg("<F9>", "n") ~= "")

  translator.setup({ keymap = false, config_keymap = false })

  eq("", vim.fn.maparg("<F9>", "n"))
end)

test("does not bind a settings menu keymap unless configured", function()
  translator.setup({ keymap = false })

  eq("", vim.fn.maparg("<F9>", "n"))
end)

test("plugin auto-loading preserves setup already applied by a plugin manager", function()
  translator.setup({ keymap = "<F8>" })
  vim.g.loaded_enpfr = nil

  dofile("plugin/enpfr.lua")

  assert(vim.fn.maparg("<F8>", "x") ~= "")
  eq("", vim.fn.maparg("<leader>enpfr", "x"))
end)

test("runs a backend asynchronously without changing the source buffer", function()
  vim.cmd("silent! only")
  vim.cmd("enew")
  local source_window = vim.api.nvim_get_current_win()
  local source_buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(source_buffer, 0, -1, false, { "This are original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  vim.fn.writefile({
    "#!/bin/sh",
    "printf '%s\\n' '{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"This is revised.\"}'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.polish_visual({
      range = 1,
      line1 = 1,
      line2 = 1,
      fargs = { "claude" },
    })

    local completed = vim.wait(2000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
          and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "This is revised."
        then
          return true
        end
      end
      return false
    end)

    eq(true, completed)
    eq(source_window, vim.api.nvim_get_current_win())
    eq({ "This are original." }, vim.api.nvim_buf_get_lines(source_buffer, 0, -1, false))
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("runs the Agy backend asynchronously without changing the source buffer", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  local source_window = vim.api.nvim_get_current_win()
  local source_buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(source_buffer, 0, -1, false, { "This are original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/agy"
  vim.fn.writefile({
    "#!/bin/sh",
    "printf '%s\\n' '{\"event\":\"result\",\"result\":{\"status\":\"SUCCESS\",\"response\":\"This is revised.\"}}'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.polish_visual({
      range = 1,
      line1 = 1,
      line2 = 1,
      fargs = { "agy" },
    })

    local completed = vim.wait(2000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
          and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "This is revised."
        then
          return true
        end
      end
      return false
    end)

    eq(true, completed)
    eq(source_window, vim.api.nvim_get_current_win())
    eq({ "This are original." }, vim.api.nvim_buf_get_lines(source_buffer, 0, -1, false))
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("marks the output as cancelled and ignores late output", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  vim.fn.writefile({
    "#!/bin/sh",
    "sleep 1",
    "printf '%s\\n' '{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"Too late.\"}'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })
    translator.cancel()

    local cancelled = vim.wait(1000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
          and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "Request cancelled."
        then
          return true
        end
      end
      return false
    end)
    eq(true, cancelled)
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("rejects selections above the configured input limit", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Too much text." })
  translator.setup({ keymap = false, max_input_bytes = 5 })

  translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = {} })

  eq(1, #vim.api.nvim_tabpage_list_wins(0))
end)

test("stops requests after the configured timeout", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  vim.fn.writefile({ "#!/bin/sh", "sleep 1" }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.setup({ keymap = false, timeout_ms = 20 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local timed_out = vim.wait(1000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
          and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "Request timed out."
        then
          return true
        end
      end
      return false
    end)
    eq(true, timed_out)
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("stops collecting backend output above the configured limit", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  vim.fn.writefile({
    "#!/bin/sh",
    "printf '%s\\n' '{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"Long output.\"}'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.setup({ keymap = false, max_output_bytes = 10 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local limited = vim.wait(1000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
        then
          local text = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
          if text:match("Backend output exceeded 10 bytes") then
            return true
          end
        end
      end
      return false
    end)
    eq(true, limited)
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("waits for stdout EOF after the backend process exits", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  vim.fn.writefile({
    "#!/bin/sh",
    "sleep 0.05",
    "printf '%s\\n' '{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"Delayed output.\"}'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.setup({ keymap = false, timeout_ms = 1000 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local completed = vim.wait(1000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
          and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "Delayed output."
        then
          return true
        end
      end
      return false
    end)
    eq(true, completed)
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("does not finalize until exit and both stream EOF signals arrive", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local original = {
    executable = vim.fn.executable,
    jobstart = vim.fn.jobstart,
    chansend = vim.fn.chansend,
    chanclose = vim.fn.chanclose,
  }
  local callbacks
  vim.fn.executable = function() return 1 end
  vim.fn.jobstart = function(_, options)
    callbacks = options
    return 42
  end
  vim.fn.chansend = function() return 1 end
  vim.fn.chanclose = function() return 1 end

  local ok, err = pcall(function()
    translator.setup({ keymap = false, timeout_ms = 1000 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local output_buffer
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buffer)
        and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
      then
        output_buffer = buffer
      end
    end
    assert(output_buffer, "output buffer was not created")

    callbacks.on_exit(42, 0)
    assert(vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1]:match("^Polishing with"))

    callbacks.on_stdout(42, {
      '{"type":"result","subtype":"success","result":"Complete output."}',
    })
    callbacks.on_stdout(42, { "" })
    assert(vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1]:match("^Polishing with"))

    callbacks.on_stderr(42, { "" })
    eq("Complete output.", vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1])
    eq(0, vim.fn.isdirectory(callbacks.cwd))
  end)

  vim.fn.executable = original.executable
  vim.fn.jobstart = original.jobstart
  vim.fn.chansend = original.chansend
  vim.fn.chanclose = original.chanclose
  assert(ok, err)
end)

test("shows the assumed default model in the status line when none is configured", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local original = {
    executable = vim.fn.executable,
    jobstart = vim.fn.jobstart,
    chansend = vim.fn.chansend,
    chanclose = vim.fn.chanclose,
  }
  vim.fn.executable = function() return 1 end
  vim.fn.jobstart = function() return 42 end
  vim.fn.chansend = function() return 1 end
  vim.fn.chanclose = function() return 1 end

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false, timeout_ms = 1000 })
    -- No model configured and none passed to :EnPfr, so the plugin must
    -- resolve backends.default_model("claude", ...) to label this line.
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local output_buffer
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buffer)
        and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
      then
        output_buffer = buffer
      end
    end
    assert(output_buffer, "output buffer was not created")

    -- Immediate feedback shows before the default model is known.
    eq("Polishing with claude...", vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1])

    local updated = vim.wait(200, function()
      return vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1] == "Polishing with claude (haiku)..."
    end)
    eq(true, updated)
  end)

  vim.fn.executable = original.executable
  vim.fn.jobstart = original.jobstart
  vim.fn.chansend = original.chansend
  vim.fn.chanclose = original.chanclose
  assert(ok, err)
end)

test("a late-arriving default model resolution never overwrites a finished result", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local original = {
    executable = vim.fn.executable,
    jobstart = vim.fn.jobstart,
    chansend = vim.fn.chansend,
    chanclose = vim.fn.chanclose,
  }
  local callbacks
  vim.fn.executable = function() return 1 end
  vim.fn.jobstart = function(_, options)
    callbacks = options
    return 42
  end
  vim.fn.chansend = function() return 1 end
  vim.fn.chanclose = function() return 1 end

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false, timeout_ms = 1000 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local output_buffer
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buffer)
        and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
      then
        output_buffer = buffer
      end
    end
    assert(output_buffer, "output buffer was not created")

    -- Finish the request before the deferred default_model() lookup (still
    -- pending on the event loop from polish_visual above) has a chance to
    -- fire and call set_status() again.
    callbacks.on_stdout(42, {
      '{"type":"result","subtype":"success","result":"Complete output."}',
    })
    callbacks.on_stdout(42, { "" })
    callbacks.on_stderr(42, { "" })
    callbacks.on_exit(42, 0)
    eq("Complete output.", vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1])

    -- Let the pending default_model() callback actually run and confirm it
    -- was a no-op against the already-finalized buffer.
    vim.wait(100)
    eq("Complete output.", vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1])
  end)

  vim.fn.executable = original.executable
  vim.fn.jobstart = original.jobstart
  vim.fn.chansend = original.chansend
  vim.fn.chanclose = original.chanclose
  assert(ok, err)
end)

test("finalizes shortly after exit even if a stream never sends EOF", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local original = {
    executable = vim.fn.executable,
    jobstart = vim.fn.jobstart,
    chansend = vim.fn.chansend,
    chanclose = vim.fn.chanclose,
  }
  local callbacks
  vim.fn.executable = function() return 1 end
  vim.fn.jobstart = function(_, options)
    callbacks = options
    return 42
  end
  vim.fn.chansend = function() return 1 end
  vim.fn.chanclose = function() return 1 end

  local ok, err = pcall(function()
    -- timeout_ms is intentionally large: this test proves recovery happens
    -- via the short post-exit grace period, not via the full request timeout.
    translator.setup({ keymap = false, timeout_ms = 60000, exit_grace_ms = 30 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local output_buffer
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buffer)
        and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
      then
        output_buffer = buffer
      end
    end
    assert(output_buffer, "output buffer was not created")

    -- stdout delivers the complete answer but never signals EOF (simulates a
    -- backend that leaves a descendant process holding the pipe open).
    callbacks.on_stdout(42, {
      '{"type":"result","subtype":"success","result":"Recovered output."}',
    })
    callbacks.on_exit(42, 0)
    -- stderr also never signals EOF.

    local recovered = vim.wait(2000, function()
      return vim.api.nvim_buf_get_lines(output_buffer, 0, 1, false)[1] == "Recovered output."
    end)
    eq(true, recovered)
    eq(0, vim.fn.isdirectory(callbacks.cwd))
  end)

  vim.fn.executable = original.executable
  vim.fn.jobstart = original.jobstart
  vim.fn.chansend = original.chansend
  vim.fn.chanclose = original.chanclose
  assert(ok, err)
end)

test("collapses and truncates long backend error text before notifying", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  local long_reason = string.rep("This request could not be completed. ", 20)
  vim.fn.writefile({
    "#!/bin/sh",
    "printf '%s\\n' '"
      .. vim.json.encode({
        type = "result",
        subtype = "error",
        is_error = true,
        result = "Line one.\nLine two.\n" .. long_reason,
      }):gsub("'", "'\\''")
      .. "'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local captured
  local original_notify = vim.notify
  vim.notify = function(message, level)
    captured = { message = message, level = level }
  end

  local ok, err = pcall(function()
    translator.setup({ keymap = false, timeout_ms = 1000 })
    translator.polish_visual({ range = 1, line1 = 1, line2 = 1, fargs = { "claude" } })

    local notified = vim.wait(1000, function()
      return captured ~= nil
    end)
    eq(true, notified)
    assert(not captured.message:match("\n"), "notification must not contain newlines")
    assert(#captured.message < 250, "notification must be short: " .. #captured.message)

    local output_buffer
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buffer)
        and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
      then
        output_buffer = buffer
      end
    end
    local full_text = table.concat(vim.api.nvim_buf_get_lines(output_buffer, 0, -1, false), "\n")
    assert(full_text:match("Line two"), "buffer should keep the full untruncated error text")
  end)

  vim.notify = original_notify
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)

test("executes the complete workflow through the visual F8 mapping", function()
  vim.cmd("silent! only")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This are original." })

  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local executable = directory .. "/claude"
  vim.fn.writefile({
    "#!/bin/sh",
    "printf '%s\\n' '{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"This is revised.\"}'",
  }, executable)
  vim.fn.setfperm(executable, "rwx------")

  local original_path = vim.env.PATH
  vim.env.PATH = directory .. ":" .. original_path
  local ok, err = pcall(function()
    translator.setup({ keymap = "<F8>", timeout_ms = 1000 })
    vim.cmd("normal! gg0v$")
    local key = vim.api.nvim_replace_termcodes("<F8>", true, false, true)
    vim.api.nvim_feedkeys(key, "x", false)

    local completed = vim.wait(1000, function()
      for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_name(buffer):match("%[English Polish")
          and vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "This is revised."
        then
          return true
        end
      end
      return false
    end)
    eq(true, completed)
  end)
  vim.env.PATH = original_path
  vim.fn.delete(directory, "rf")
  assert(ok, err)
end)
