local M = {}

local supported = {
  claude = true,
  codex = true,
  opencode = true,
  agy = true,
}

local function check_backend(name)
  if not supported[name] then
    error("Unsupported backend: " .. tostring(name))
  end
end

local function add_model(command, model)
  if model and model ~= "" then
    command[#command + 1] = "--model"
    command[#command + 1] = model
  end
end

function M.command(name, model)
  check_backend(name)

  local command
  if name == "claude" then
    command = {
      "claude",
      "-p",
      "--safe-mode",
      "--tools",
      "",
      "--no-session-persistence",
      "--output-format",
      "json",
    }
  elseif name == "codex" then
    command = {
      "codex",
      "exec",
      "--ephemeral",
      "--sandbox",
      "read-only",
      "--skip-git-repo-check",
      "--ignore-user-config",
      "--ignore-rules",
      "--json",
    }
  elseif name == "opencode" then
    command = { "opencode", "run", "--pure", "--format", "json" }
  else
    command = {
      "agy",
      "--input-format",
      "stream-json",
      "--output-format",
      "stream-json",
      "--sandbox",
    }
  end

  add_model(command, model)
  if name == "codex" then
    command[#command + 1] = "-"
  end
  return command
end

local function decode_json(line)
  local ok, value = pcall(vim.json.decode, line)
  if not ok then
    return nil, "Invalid JSON from backend: " .. value
  end
  return value
end

local function parse_json_lines(output, text_from_event)
  local parts = {}
  for line in output:gmatch("[^\r\n]+") do
    local event, err = decode_json(line)
    if err then
      return nil, err
    end
    if type(event) ~= "table" then
      return nil, "Backend JSON event must be an object"
    end
    local text, event_error = text_from_event(event)
    if event_error then
      return nil, event_error
    end
    if text ~= nil then
      if type(text) ~= "string" then
        return nil, "Backend text must be a string"
      end
      parts[#parts + 1] = text
    end
  end

  if #parts == 0 then
    return nil, "Backend returned no revised text"
  end
  return table.concat(parts)
end

function M.parse(name, output)
  check_backend(name)

  if name == "claude" then
    local result, err = decode_json(output)
    if err then
      return nil, err
    end
    if type(result) ~= "table" then
      return nil, "Claude JSON result must be an object"
    end
    if result.is_error or result.subtype ~= "success" then
      local message = type(result.result) == "string" and result.result or "Claude request failed"
      return nil, message
    end
    if type(result.result) ~= "string" or result.result == "" then
      return nil, "Claude returned no revised text"
    end
    return result.result
  end

  if name == "agy" then
    local final_result
    for line in output:gmatch("[^\r\n]+") do
      local event, err = decode_json(line)
      if err then
        return nil, err
      end
      if type(event) ~= "table" then
        return nil, "Agy JSON event must be an object"
      end
      if event.event == "result" then
        final_result = event.result
      end
    end
    if type(final_result) ~= "table" then
      return nil, "Agy returned no result event"
    end
    if final_result.status ~= "SUCCESS" then
      local message = (type(final_result.error) == "string" and final_result.error ~= "")
          and final_result.error
        or ("Agy request status: " .. tostring(final_result.status))
      return nil, message
    end
    if type(final_result.response) ~= "string" or final_result.response == "" then
      return nil, "Agy returned no revised text"
    end
    return final_result.response
  end

  if name == "codex" then
    local final_text
    local _, err = parse_json_lines(output, function(event)
      if event.type == "item.completed"
        and type(event.item) == "table"
        and event.item.type == "agent_message"
      then
        if type(event.item.text) ~= "string" then
          return nil, "Codex agent message text must be a string"
        end
        final_text = event.item.text
        return ""
      end
    end)
    if err then
      return nil, err
    end
    if not final_text or final_text == "" then
      return nil, "Backend returned no revised text"
    end
    return final_text
  end

  return parse_json_lines(output, function(event)
    if event.type == "text" and type(event.part) ~= "table" then
      return nil, "OpenCode text event part must be an object"
    end
    if event.type == "text" and event.part.type == "text" then
      return event.part.text
    end
  end)
end

function M.environment(name)
  check_backend(name)
  if name ~= "opencode" then
    return nil
  end

  return {
    OPENCODE_CONFIG_CONTENT = vim.json.encode({
      permission = { ["*"] = "deny" },
      tools = {
        write = false,
        edit = false,
        bash = false,
        apply_patch = false,
      },
      share = "disabled",
      snapshot = false,
    }),
  }
end

function M.stdin_payload(name, prompt_text)
  check_backend(name)
  if name ~= "agy" then
    return prompt_text
  end
  return vim.json.encode({ event = "user", message = { content = prompt_text } }) .. "\n"
end

function M.names()
  return { "claude", "codex", "opencode", "agy" }
end

local model_list_commands = {
  opencode = { "opencode", "models" },
  agy = { "agy", "models" },
}

-- Best-effort static fallback for backends with no listing subcommand today.
-- Neither claude nor codex expose one (verified against `claude --help` /
-- `codex --help`; both have open, unimplemented upstream feature requests
-- for it). Not authoritative and may drift from what an account can
-- actually use; the settings menu always keeps a manual-entry escape hatch.
local known_models = {
  claude = { "haiku", "sonnet", "opus", "fable" },
  codex = { "gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol" },
}

function M.model_list_command(name)
  check_backend(name)
  return model_list_commands[name]
end

function M.known_models(name)
  check_backend(name)
  return known_models[name] or {}
end

function M.parse_model_list(name, output)
  check_backend(name)
  local models = {}
  if name == "opencode" then
    for line in output:gmatch("[^\r\n]+") do
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed ~= "" then
        models[#models + 1] = trimmed
      end
    end
  elseif name == "agy" then
    for line in output:gmatch("[^\r\n]+") do
      local id = line:match("^%s*([^\t]+)")
      if id and id ~= "" then
        models[#models + 1] = id
      end
    end
  end
  return models
end

-- Single entry point for callers: regardless of whether a backend supports
-- live listing, on_done is always invoked asynchronously with a plain array
-- of model-name strings, so callers never need to branch on backend tier.
function M.fetch_models(name, on_done)
  check_backend(name)
  local command = model_list_commands[name]
  if not command then
    vim.schedule(function()
      on_done(known_models[name] or {})
    end)
    return
  end

  local stdout = {}
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        on_done({})
        return
      end
      on_done(M.parse_model_list(name, table.concat(stdout, "\n")))
    end,
  })
end

-- Agy has no listing subcommand result to lean on for "which model is the
-- default" the way opencode's live list does, and it has no known_models
-- fallback list either (fetch_models("agy", ...) always hits the live
-- `agy models` command). This is the account's actual default model on the
-- machine this was verified against (~/.gemini/antigravity-cli/settings.json
-- -> "model": "Gemini 3.8 Flash (Medium)"), hardcoded because there is no
-- portable, general way to read a user's own Agy config from here.
local AGY_DEFAULT_MODEL = "gemini-3.8-flash-medium"

local function resolve_default_model(name, on_done)
  if name == "agy" then
    vim.schedule(function()
      on_done(AGY_DEFAULT_MODEL)
    end)
    return
  end
  if name == "opencode" then
    M.fetch_models("opencode", function(models)
      on_done(models[1])
    end)
    return
  end
  vim.schedule(function()
    on_done((known_models[name] or {})[1])
  end)
end

-- Caches the resolved default per backend for the life of this Neovim
-- session. Only opencode's answer costs a real subprocess call (a fresh
-- `opencode models` run); callers that need this on every polish request
-- (init.lua, to label "Polishing with ..." when no model is configured) and
-- every settings-menu render (config_ui.lua) would otherwise re-run it just
-- to redraw one line of text. Call M.clear_default_cache() to force a fresh
-- lookup (e.g. after the account's available models actually changed).
local default_model_cache = {}

-- The model name a backend uses when no model is configured, for display
-- purposes only (it is never passed as --model; the CLI's own default still
-- applies). Always asynchronous via on_done, matching fetch_models, since
-- opencode's answer requires an actual subprocess call the first time.
function M.default_model(name, on_done)
  check_backend(name)
  if default_model_cache[name] ~= nil then
    on_done(default_model_cache[name] or nil)
    return
  end
  resolve_default_model(name, function(model_name)
    default_model_cache[name] = model_name or false
    on_done(model_name)
  end)
end

function M.clear_default_cache()
  default_model_cache = {}
end

return M
