local backends = require("enpfr.backends")

test("builds a non-interactive Claude command", function()
  local command = backends.command("claude", "sonnet")

  eq({
    "claude",
    "-p",
    "--safe-mode",
    "--tools",
    "",
    "--no-session-persistence",
    "--output-format",
    "json",
    "--model",
    "sonnet",
  }, command)
end)

test("builds a read-only ephemeral Codex command", function()
  local command = backends.command("codex", "gpt-5.4-mini")

  eq({
    "codex",
    "exec",
    "--ephemeral",
    "--sandbox",
    "read-only",
    "--skip-git-repo-check",
    "--ignore-user-config",
    "--ignore-rules",
    "--json",
    "--model",
    "gpt-5.4-mini",
    "-",
  }, command)
end)

test("builds a non-interactive OpenCode command", function()
  local command = backends.command("opencode", nil)

  eq({ "opencode", "run", "--standalone", "--format", "json" }, command)
end)

test("builds a sandboxed stream-json Agy command", function()
  local command = backends.command("agy", "gemini-3.8-flash-high")

  eq({
    "agy",
    "--input-format",
    "stream-json",
    "--output-format",
    "stream-json",
    "--sandbox",
    "--model",
    "gemini-3.8-flash-high",
  }, command)
end)

test("parses Claude's result object", function()
  local output = '{"type":"result","subtype":"success","result":"Revised text."}'

  eq("Revised text.", backends.parse("claude", output))
end)

test("parses the final Codex agent message", function()
  local output = table.concat({
    '{"type":"thread.started","thread_id":"123"}',
    '{"type":"item.completed","item":{"type":"agent_message","text":"Working on it."}}',
    '{"type":"item.completed","item":{"type":"agent_message","text":"Revised text."}}',
    '{"type":"turn.completed"}',
  }, "\n")

  eq("Revised text.", backends.parse("codex", output))
end)

test("joins OpenCode text events", function()
  local output = table.concat({
    '{"type":"step_start"}',
    '{"type":"text","part":{"type":"text","text":"Revised "}}',
    '{"type":"text","part":{"type":"text","text":"text."}}',
  }, "\n")

  eq("Revised text.", backends.parse("opencode", output))
end)

test("parses the final Agy result event", function()
  local output = table.concat({
    vim.json.encode({ event = "init", conversation_id = "123" }),
    vim.json.encode({ event = "step_update", step_update = { state = "ACTIVE" } }),
    vim.json.encode({ event = "result", result = { status = "SUCCESS", response = "Revised text." } }),
  }, "\n")

  eq("Revised text.", backends.parse("agy", output))
end)

test("reports an Agy error status", function()
  local output = vim.json.encode({
    event = "result",
    result = { status = "ERROR", error = "quota exceeded" },
  })

  local revised, err = backends.parse("agy", output)
  eq(nil, revised)
  assert(err:match("quota exceeded"), err)
end)

test("reports a non-success Agy status without an error field", function()
  local output = vim.json.encode({ event = "result", result = { status = "CANCELED" } })

  local revised, err = backends.parse("agy", output)
  eq(nil, revised)
  assert(err:match("CANCELED"), err)
end)

test("reports missing Agy result event", function()
  local output = vim.json.encode({ event = "init", conversation_id = "123" })

  local revised, err = backends.parse("agy", output)
  eq(nil, revised)
  assert(err:match("no result event"), err)
end)

test("wraps the prompt in a stream-json user event for Agy", function()
  local payload = backends.stdin_payload("agy", "Fix this.")

  eq({ event = "user", message = { content = "Fix this." } }, vim.json.decode(payload))
end)

test("leaves the prompt unchanged for other backends", function()
  eq("Fix this.", backends.stdin_payload("claude", "Fix this."))
  eq("Fix this.", backends.stdin_payload("codex", "Fix this."))
  eq("Fix this.", backends.stdin_payload("opencode", "Fix this."))
end)

test("rejects an unsupported backend", function()
  local ok, err = pcall(backends.command, "unknown", nil)

  eq(false, ok)
  assert(err:match("Unsupported backend"), err)
end)

test("reports malformed backend JSON shapes without throwing", function()
  local revised, err = backends.parse("claude", "null")
  eq(nil, revised)
  assert(err:match("object"), err)

  revised, err = backends.parse("codex", "42")
  eq(nil, revised)
  assert(err:match("object"), err)

  revised, err = backends.parse("opencode", '{"type":"text","part":42}')
  eq(nil, revised)
  assert(err:match("part"), err)

  revised, err = backends.parse("claude", "false")
  eq(nil, revised)
  assert(err:match("object"), err)

  revised, err = backends.parse("agy", "null")
  eq(nil, revised)
  assert(err:match("object"), err)
end)

test("disables all OpenCode tools through inline configuration", function()
  local environment = backends.environment("opencode")
  local inline_config = vim.json.decode(environment.OPENCODE_CONFIG_CONTENT)

  eq("deny", inline_config.permission["*"])
  eq(false, inline_config.tools.write)
  eq(false, inline_config.tools.edit)
  eq(false, inline_config.tools.bash)
  eq({ "-*", "opencode.*" }, inline_config.plugins)
  eq("disabled", inline_config.share)
end)

test("returns the live model-list command for opencode and agy", function()
  eq({ "opencode", "models" }, backends.model_list_command("opencode"))
  eq({ "agy", "models" }, backends.model_list_command("agy"))
end)

test("returns no live model-list command for claude and codex", function()
  eq(nil, backends.model_list_command("claude"))
  eq(nil, backends.model_list_command("codex"))
end)

test("parses one opencode model per line", function()
  local output = "opencode/big-pickle\nopenai/gpt-5.4\nopenai/gpt-5.4-mini\n"
  eq(
    { "opencode/big-pickle", "openai/gpt-5.4", "openai/gpt-5.4-mini" },
    backends.parse_model_list("opencode", output)
  )
end)

test("parses only the model id from tab-separated agy output", function()
  local output = "gemini-3.8-flash-high\tGemini 3.8 Flash (High)\n"
    .. "claude-sonnet-4-6\tClaude Sonnet 4.6 (Thinking)\n"
  eq(
    { "gemini-3.8-flash-high", "claude-sonnet-4-6" },
    backends.parse_model_list("agy", output)
  )
end)

test("returns an empty model list instead of erroring on blank output", function()
  eq({}, backends.parse_model_list("opencode", ""))
  eq({}, backends.parse_model_list("agy", ""))
end)

test("known_models returns a small static list only for claude and codex", function()
  assert(#backends.known_models("claude") > 0)
  assert(#backends.known_models("codex") > 0)
  eq({}, backends.known_models("opencode"))
  eq({}, backends.known_models("agy"))
end)

test("fetch_models runs the live command for opencode", function()
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(command, options)
    eq({ "opencode", "models" }, command)
    options.on_stdout(nil, { "opencode/big-pickle", "openai/gpt-5.4" })
    options.on_exit(nil, 0)
    return 1
  end

  local result
  backends.fetch_models("opencode", function(models)
    result = models
  end)

  vim.fn.jobstart = original_jobstart
  eq({ "opencode/big-pickle", "openai/gpt-5.4" }, result)
end)

test("fetch_models returns an empty list when the live command exits non-zero", function()
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(_, options)
    options.on_exit(nil, 1)
    return 1
  end

  local result
  backends.fetch_models("agy", function(models)
    result = models
  end)

  vim.fn.jobstart = original_jobstart
  eq({}, result)
end)

test("fetch_models stops a hung list command after the timeout with an empty list", function()
  local original_jobstart = vim.fn.jobstart
  local original_jobstop = vim.fn.jobstop
  local original_defer_fn = vim.defer_fn
  local stopped
  local timeout_callback
  vim.fn.jobstart = function(_, _)
    return 1 -- a stuck CLI: on_exit is never called
  end
  vim.fn.jobstop = function(job_id)
    stopped = job_id
  end
  vim.defer_fn = function(fn, delay)
    timeout_callback = { fn = fn, delay = delay }
  end

  local calls = 0
  local result
  backends.fetch_models("opencode", function(models)
    calls = calls + 1
    result = models
  end, 100)

  eq(nil, result)
  eq(100, timeout_callback.delay)

  timeout_callback.fn()
  eq(1, stopped)
  eq({}, result)
  eq(1, calls)

  -- The killed job's on_exit (and any repeat invocation) must not double-deliver.
  timeout_callback.fn()
  eq(1, calls)

  vim.defer_fn = original_defer_fn
  vim.fn.jobstop = original_jobstop
  vim.fn.jobstart = original_jobstart
end)

test("fetch_models applies a default deadline when none is given", function()
  local original_jobstart = vim.fn.jobstart
  local original_defer_fn = vim.defer_fn
  local timeout_callback
  vim.fn.jobstart = function(_, _)
    return 1
  end
  vim.defer_fn = function(fn, delay)
    timeout_callback = { fn = fn, delay = delay }
  end

  backends.fetch_models("opencode", function() end)

  eq(30000, timeout_callback.delay)

  vim.defer_fn = original_defer_fn
  vim.fn.jobstart = original_jobstart
end)

test("fetch_models falls back to the static list for claude without spawning a job", function()
  local original_jobstart = vim.fn.jobstart
  local spawned = false
  vim.fn.jobstart = function()
    spawned = true
    return 1
  end

  local result
  backends.fetch_models("claude", function(models)
    result = models
  end)
  vim.wait(100, function()
    return result ~= nil
  end)

  vim.fn.jobstart = original_jobstart
  eq(false, spawned)
  eq(backends.known_models("claude"), result)
end)

test("default_model uses the first known model for claude and codex", function()
  local claude_result, codex_result
  backends.default_model("claude", function(model) claude_result = model end)
  backends.default_model("codex", function(model) codex_result = model end)
  vim.wait(100, function()
    return claude_result ~= nil and codex_result ~= nil
  end)

  eq("haiku", claude_result)
  eq("gpt-5.6-luna", codex_result)
end)

test("default_model uses a hardcoded model for agy without spawning a job", function()
  local original_jobstart = vim.fn.jobstart
  local spawned = false
  vim.fn.jobstart = function()
    spawned = true
    return 1
  end

  local result
  backends.default_model("agy", function(model)
    result = model
  end)
  vim.wait(100, function()
    return result ~= nil
  end)

  vim.fn.jobstart = original_jobstart
  eq(false, spawned)
  eq("gemini-3.8-flash-medium", result)
end)

test("default_model uses the first live-fetched model for opencode", function()
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(command, options)
    eq({ "opencode", "models" }, command)
    options.on_stdout(nil, { "opencode/big-pickle", "openai/gpt-5.4" })
    options.on_exit(nil, 0)
    return 1
  end

  local result
  backends.default_model("opencode", function(model)
    result = model
  end)

  vim.fn.jobstart = original_jobstart
  eq("opencode/big-pickle", result)
end)

test("default_model caches opencode's result instead of re-fetching", function()
  backends.clear_default_cache()
  local original_jobstart = vim.fn.jobstart
  local calls = 0
  vim.fn.jobstart = function(_, options)
    calls = calls + 1
    options.on_stdout(nil, { "opencode/big-pickle" })
    options.on_exit(nil, 0)
    return 1
  end

  local first, second
  backends.default_model("opencode", function(model) first = model end)
  backends.default_model("opencode", function(model) second = model end)

  vim.fn.jobstart = original_jobstart
  eq(1, calls)
  eq("opencode/big-pickle", first)
  eq("opencode/big-pickle", second)

  backends.clear_default_cache()
end)
