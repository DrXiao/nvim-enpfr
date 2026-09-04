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

test("builds a pure OpenCode command", function()
  local command = backends.command("opencode", nil)

  eq({ "opencode", "run", "--pure", "--format", "json" }, command)
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
  eq("disabled", inline_config.share)
end)
