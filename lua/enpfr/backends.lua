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

return M
