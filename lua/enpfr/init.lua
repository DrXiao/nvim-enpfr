local backends = require("enpfr.backends")
local output = require("enpfr.output")
local prompt = require("enpfr.prompt")
local selection = require("enpfr.selection")

local M = {}

local defaults = {
  backend = "claude",
  models = {
    claude = nil,
    codex = nil,
    opencode = nil,
  },
  keymap = "<leader>ep",
  max_input_bytes = 50000,
  max_output_bytes = 200000,
  timeout_ms = 120000,
  exit_grace_ms = 200,
}

local config = vim.deepcopy(defaults)
local active_request
local request_id = 0
local configured_keymap
local configured = false

local NOTIFY_MAX_LENGTH = 200

-- Collapse whitespace/newlines and cap length so a long or multiline
-- backend message (e.g. a Claude API refusal explanation) can never make
-- Neovim's message area trigger the "Press ENTER" prompt, which blocks all
-- keyboard input until dismissed. The full text is still written to the
-- read-only output buffer via output.set_text().
local function summarize_for_notify(message)
  local collapsed = tostring(message):gsub("%s+", " ")
  if #collapsed > NOTIFY_MAX_LENGTH then
    return collapsed:sub(1, NOTIFY_MAX_LENGTH) .. "..."
  end
  return collapsed
end

local function notify(message, level)
  vim.notify("enpfr: " .. summarize_for_notify(message), level or vim.log.levels.INFO)
end

local function is_supported(name)
  for _, backend in ipairs(backends.names()) do
    if backend == name then
      return true
    end
  end
  return false
end

local function append_stream(target, data, budget)
  if not data or budget.exceeded then
    return not budget.exceeded
  end

  local added_bytes = math.max(#data - 1, 0)
  for _, line in ipairs(data) do
    added_bytes = added_bytes + #line
  end
  if budget.used + added_bytes > budget.maximum then
    budget.exceeded = true
    return false
  end
  budget.used = budget.used + added_bytes

  target[#target] = target[#target] .. (data[1] or "")
  for index = 2, #data do
    target[#target + 1] = data[index]
  end
  return true
end

local function format_error(message, stderr)
  local details = message
  if stderr ~= "" then
    details = details .. "\n\n" .. stderr
  end
  return "Request failed\n\n" .. details
end

local function start_request(text, backend, model, source_window, filetype)
  local destination = output.open(source_window, filetype)
  request_id = request_id + 1
  local current_request = request_id
  if active_request then
    local previous = active_request
    vim.fn.jobstop(previous.job_id)
    vim.fn.delete(previous.working_directory, "rf")
    active_request = nil
  end

  if vim.fn.executable(backend) ~= 1 then
    local message = "Executable not found: " .. backend
    output.set_text(destination.buffer, format_error(message, ""))
    notify(message, vim.log.levels.ERROR)
    return
  end

  local model_label = model and (" (" .. model .. ")") or ""
  output.set_text(destination.buffer, "Polishing with " .. backend .. model_label .. "...")

  local working_directory = vim.fn.tempname()
  if vim.fn.mkdir(working_directory, "p", 448) == 0 then
    local message = "Could not create an isolated working directory"
    output.set_text(destination.buffer, format_error(message, ""))
    notify(message, vim.log.levels.ERROR)
    return
  end

  local stdout = { "" }
  local stderr = { "" }
  local output_budget = {
    used = 0,
    maximum = config.max_output_bytes,
    exceeded = false,
  }
  local state = {
    exited = false,
    exit_code = nil,
    stdout_eof = false,
    stderr_eof = false,
    finalized = false,
  }
  local command = backends.command(backend, model)

  local function finalize(force)
    if state.finalized or not state.exited then
      return
    end
    if not force and not (state.stdout_eof and state.stderr_eof) then
      return
    end
    state.finalized = true
    vim.fn.delete(working_directory, "rf")

    if current_request ~= request_id then
      return
    end
    active_request = nil

    local error_output = table.concat(stderr, "\n")
    if output_budget.exceeded then
      local message = "Backend output exceeded " .. output_budget.maximum .. " bytes"
      output.set_text(destination.buffer, format_error(message, error_output))
      notify(message, vim.log.levels.ERROR)
      return
    end
    if state.exit_code ~= 0 then
      local message = "Backend exited with status " .. state.exit_code
      output.set_text(destination.buffer, format_error(message, error_output))
      notify(message, vim.log.levels.ERROR)
      return
    end

    local revised, parse_error = backends.parse(backend, table.concat(stdout, "\n"))
    if not revised then
      output.set_text(destination.buffer, format_error(parse_error, error_output))
      notify(parse_error, vim.log.levels.ERROR)
      return
    end
    output.set_text(destination.buffer, revised)
  end

  local job_options = {
    cwd = working_directory,
    env = backends.environment(backend),
    on_stdout = function(job, data)
      if #data == 1 and data[1] == "" then
        state.stdout_eof = true
        finalize(false)
        return
      end
      if not append_stream(stdout, data, output_budget) then
        vim.fn.jobstop(job)
      end
    end,
    on_stderr = function(job, data)
      if #data == 1 and data[1] == "" then
        state.stderr_eof = true
        finalize(false)
        return
      end
      if not append_stream(stderr, data, output_budget) then
        vim.fn.jobstop(job)
      end
    end,
    on_exit = function(_, exit_code)
      state.exited = true
      state.exit_code = exit_code
      finalize(false)
      if not state.finalized then
        -- The direct child process has exited, but at least one stream
        -- (stdout/stderr) has not signalled EOF. This happens when the CLI
        -- leaves a descendant process holding the pipe open (an observed
        -- pattern with backend daemon/sandbox architectures). Rather than
        -- waiting indefinitely for an EOF that may never arrive, finalize
        -- with whatever output was collected after a short grace period.
        vim.defer_fn(function()
          finalize(true)
        end, config.exit_grace_ms)
      end
    end,
  }
  local job_id = vim.fn.jobstart(command, job_options)

  if job_id <= 0 then
    vim.fn.delete(working_directory, "rf")
    local message = "Could not start " .. backend
    output.set_text(destination.buffer, format_error(message, ""))
    notify(message, vim.log.levels.ERROR)
    return
  end
  active_request = {
    job_id = job_id,
    buffer = destination.buffer,
    request_id = current_request,
    working_directory = working_directory,
  }
  vim.fn.chansend(job_id, prompt.build(text))
  vim.fn.chanclose(job_id, "stdin")

  vim.defer_fn(function()
    if active_request and active_request.request_id == current_request then
      request_id = request_id + 1
      local timed_out = active_request
      active_request = nil
      vim.fn.jobstop(timed_out.job_id)
      vim.fn.delete(timed_out.working_directory, "rf")
      output.set_text(timed_out.buffer, "Request timed out.")
      notify("Request timed out", vim.log.levels.ERROR)
    end
  end, config.timeout_ms)
end

local function selection_from_command(command)
  if command.range == 0 then
    return nil, "Select English text in visual mode before running :EnPfr"
  end

  local buffer = vim.api.nvim_get_current_buf()
  local first = vim.api.nvim_buf_get_mark(buffer, "<")
  local last = vim.api.nvim_buf_get_mark(buffer, ">")
  local mode = vim.fn.visualmode()
  local visual_range = first[1] == command.line1
    and last[1] == command.line2
    and (mode == "v" or mode == "V" or mode == "\22")

  if not visual_range then
    local last_line = vim.api.nvim_buf_get_lines(buffer, command.line2 - 1, command.line2, false)[1] or ""
    first = { command.line1, 0 }
    last = { command.line2, math.max(#last_line - 1, 0) }
    mode = "V"
  elseif mode == "v" and vim.o.selection == "exclusive" then
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    first, last = selection.adjust_exclusive(lines, first, last)
    if not first then
      return ""
    end
  end

  return selection.from_buffer(buffer, mode, first, last)
end

function M.polish_visual(command)
  local text, err = selection_from_command(command)
  if not text then
    notify(err, vim.log.levels.ERROR)
    return
  end
  if not text:match("%S") then
    notify("The selected text is empty", vim.log.levels.ERROR)
    return
  end
  if #text > config.max_input_bytes then
    notify(
      "Selection exceeds " .. config.max_input_bytes .. " bytes",
      vim.log.levels.ERROR
    )
    return
  end
  if #command.fargs > 2 then
    notify("Usage: EnPfr [backend] [model]", vim.log.levels.ERROR)
    return
  end

  local backend = command.fargs[1] or config.backend
  if not is_supported(backend) then
    notify("Unsupported backend: " .. backend, vim.log.levels.ERROR)
    return
  end
  local model = command.fargs[2] or config.models[backend]
  local source_window = vim.api.nvim_get_current_win()
  local filetype = vim.bo.filetype
  start_request(text, backend, model, source_window, filetype)
end

function M.cancel()
  if not active_request then
    notify("No request is running")
    return
  end

  request_id = request_id + 1
  local cancelled = active_request
  active_request = nil
  vim.fn.jobstop(cancelled.job_id)
  vim.fn.delete(cancelled.working_directory, "rf")
  output.set_text(cancelled.buffer, "Request cancelled.")
  notify("Request cancelled")
end

local function complete(argument, command_line)
  local words = vim.split(command_line, "%s+", { trimempty = true })
  local candidates = {}
  if #words <= 1 or (#words == 2 and not command_line:match("%s$")) then
    candidates = backends.names()
  else
    for _, model in pairs(config.models) do
      if model and model ~= "" then
        candidates[#candidates + 1] = model
      end
    end
  end

  return vim.tbl_filter(function(value)
    return vim.startswith(value, argument)
  end, candidates)
end

local function create_commands()
  vim.api.nvim_create_user_command("EnPfr", M.polish_visual, {
    nargs = "*",
    range = true,
    complete = complete,
    desc = "Polish visually selected English text",
    force = true,
  })
  vim.api.nvim_create_user_command("EnPfrCancel", M.cancel, {
    desc = "Cancel the active English polishing request",
    force = true,
  })
end

function M.setup(options)
  if configured_keymap then
    pcall(vim.keymap.del, "x", configured_keymap)
    configured_keymap = nil
  end
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), options or {})
  if not is_supported(config.backend) then
    error("Unsupported backend: " .. tostring(config.backend))
  end
  if type(config.models) ~= "table" then
    error("models must be a table")
  end
  for _, option in ipairs({ "max_input_bytes", "max_output_bytes", "timeout_ms", "exit_grace_ms" }) do
    if type(config[option]) ~= "number" or config[option] <= 0 then
      error(option .. " must be a positive number")
    end
  end

  create_commands()
  if config.keymap and config.keymap ~= "" then
    vim.keymap.set("x", config.keymap, ":EnPfr<CR>", {
      desc = "Polish selected English text",
      silent = true,
    })
    configured_keymap = config.keymap
  end
  configured = true
end

function M.is_configured()
  return configured
end

return M
