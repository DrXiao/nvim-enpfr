local translator = require("enpfr")
local config_ui = require("enpfr.config_ui")
local float_ui = require("enpfr.float_ui")

-- Every completed action in config_ui re-renders the top-level menu, which
-- needs an assumed "default model" label for every unconfigured backend --
-- for opencode that means running `opencode models`. Install one baseline
-- jobstart mock for this whole file so no test can accidentally shell out
-- to a real CLI just because an action's M.open() cascade reaches the
-- top-level menu. Tests that need a specific canned response override this
-- within their own pcall and must restore this baseline (not the real
-- function) afterward.
local REAL_JOBSTART = vim.fn.jobstart
local function install_baseline_jobstart()
  vim.fn.jobstart = function(_, options)
    options.on_stdout(nil, { "opencode/big-pickle" })
    options.on_exit(nil, 0)
    return 1
  end
end
install_baseline_jobstart()

test("selecting a backend from the picker updates the live config", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false, backend = "claude" })
    float_ui.select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item == "codex" then
          on_choice(item)
          return
        end
      end
      on_choice(nil)
    end

    config_ui.pick_backend()

    eq("codex", translator.get_config().backend)
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("selecting a model from the live list updates that backend's config", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    vim.fn.jobstart = function(_, options)
      options.on_stdout(nil, { "opencode/gpt-5.4" })
      options.on_exit(nil, 0)
      return 1
    end
    float_ui.select = function(items, _, on_choice)
      on_choice(items[1], 1)
    end

    config_ui.pick_model("opencode")

    eq("opencode/gpt-5.4", translator.get_config().models.opencode)
  end)

  float_ui.select = original_select
  install_baseline_jobstart()
  translator.reset_settings()
  assert(ok, err)
end)

test("manual entry escape hatch sets a model via float_ui.input", function()
  local original_select = float_ui.select
  local original_input = float_ui.input

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    local done = false
    float_ui.select = function(items, _, on_choice)
      for index, item in ipairs(items) do
        if item == "[Enter manually]" then
          on_choice(item, index)
          return
        end
      end
    end
    float_ui.input = function(_, on_confirm)
      on_confirm("opus")
      done = true
    end

    config_ui.pick_model("claude")
    vim.wait(200, function()
      return done
    end)

    eq("opus", translator.get_config().models.claude)
  end)

  float_ui.select = original_select
  float_ui.input = original_input
  translator.reset_settings()
  assert(ok, err)
end)

test("using CLI default clears a configured model", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false, models = { claude = "opus" } })
    local done = false
    float_ui.select = function(items, _, on_choice)
      for index, item in ipairs(items) do
        if item:match("^%[Use CLI default%]") then
          on_choice(item, index)
          done = true
          return
        end
      end
    end

    config_ui.pick_model("claude")
    vim.wait(200, function()
      return done
    end)

    eq(nil, translator.get_config().models.claude)
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("the CLI default entry names claude's assumed default model", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    -- Cancelling pick_model's picker falls through to M.open(), which opens
    -- a second (top-level menu) picker; capture only the first call's items
    -- so that cascade doesn't overwrite what we're actually asserting on.
    local labels
    float_ui.select = function(items, _, on_choice)
      if not labels then
        labels = items
      end
      on_choice(nil)
    end

    config_ui.pick_model("claude")
    vim.wait(200, function()
      return labels ~= nil
    end)

    local found = false
    for _, item in ipairs(labels) do
      if item == "[Use CLI default] haiku (default)" then
        found = true
      end
    end
    assert(found, vim.inspect(labels))
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("the CLI default entry names agy's hardcoded default model", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    vim.fn.jobstart = function(_, options)
      options.on_stdout(nil, { "gemini-3.8-flash-high\tGemini 3.8 Flash (High)" })
      options.on_exit(nil, 0)
      return 1
    end
    local labels
    float_ui.select = function(items, _, on_choice)
      if not labels then
        labels = items
      end
      on_choice(nil)
    end

    config_ui.pick_model("agy")
    vim.wait(200, function()
      return labels ~= nil
    end)

    local found = false
    for _, item in ipairs(labels) do
      if item == "[Use CLI default] gemini-3.8-flash-medium (default)" then
        found = true
      end
    end
    assert(found, vim.inspect(labels))
  end)

  float_ui.select = original_select
  install_baseline_jobstart()
  translator.reset_settings()
  assert(ok, err)
end)

test("reset_settings restores backend, models, and mode to defaults", function()
  local ok, err = pcall(function()
    translator.setup({ keymap = false, backend = "codex", models = { codex = "gpt-5.4" }, mode = "cs_expert" })

    translator.reset_settings()

    local config = translator.get_config()
    eq("claude", config.backend)
    eq(nil, config.models.claude)
    eq(nil, config.models.codex)
    eq("general", config.mode)
  end)

  translator.reset_settings()
  assert(ok, err)
end)

test("selecting a mode from the picker updates the live config", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    float_ui.select = function(items, _, on_choice)
      on_choice(items[2], 2)
    end

    config_ui.pick_mode()

    eq("cs_expert", translator.get_config().mode)
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("the top-level menu shows assumed defaults for unconfigured backends", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    local labels
    float_ui.select = function(items, _, on_choice)
      labels = items
      on_choice(nil)
    end

    config_ui.open()
    vim.wait(200, function()
      return labels ~= nil
    end)

    local divider = string.rep("-", 20)
    eq("Default mode: General", labels[1])
    eq(divider, labels[2])
    eq("Default backend: claude", labels[3])
    eq("Model for claude: haiku (default)", labels[4])
    eq("Model for codex: gpt-5.6-luna (default)", labels[5])
    eq("Model for opencode: opencode/big-pickle (default)", labels[6])
    eq("Model for agy: gemini-3.8-flash-medium (default)", labels[7])
    eq(divider, labels[8])
    eq("Reset all settings to defaults", labels[9])
    eq("Close", labels[10])
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("the divider row before reset/close is inert", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    local calls = 0
    float_ui.select = function(items, _, on_choice)
      calls = calls + 1
      if calls == 1 then
        on_choice(items[8], 8)
      else
        on_choice(nil)
      end
    end

    config_ui.open()
    vim.wait(200, function()
      return calls >= 2
    end)

    eq("claude", translator.get_config().backend)
    assert(calls >= 2, "selecting the divider did not redraw the menu")
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("the divider row between mode and backend settings is inert", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false })
    local calls = 0
    float_ui.select = function(items, _, on_choice)
      calls = calls + 1
      if calls == 1 then
        on_choice(items[2], 2)
      else
        on_choice(nil)
      end
    end

    config_ui.open()
    vim.wait(200, function()
      return calls >= 2
    end)

    eq("general", translator.get_config().mode)
    eq("claude", translator.get_config().backend)
    assert(calls >= 2, "selecting the divider did not redraw the menu")
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("the top-level menu shows a configured model plainly, without a default suffix", function()
  local original_select = float_ui.select

  local ok, err = pcall(function()
    require("enpfr.backends").clear_default_cache()
    translator.setup({ keymap = false, models = { claude = "opus" } })
    local labels
    float_ui.select = function(items, _, on_choice)
      labels = items
      on_choice(nil)
    end

    config_ui.open()
    vim.wait(200, function()
      return labels ~= nil
    end)

    eq("Model for claude: opus", labels[4])
  end)

  float_ui.select = original_select
  translator.reset_settings()
  assert(ok, err)
end)

test("settings changed through the picker persist across a simulated restart", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  local original_stdpath = vim.fn.stdpath
  vim.fn.stdpath = function(what)
    if what == "data" then
      return directory
    end
    return original_stdpath(what)
  end

  local ok, err = pcall(function()
    translator.setup({ keymap = false })
    translator.set_backend("codex")

    package.loaded["enpfr"] = nil
    package.loaded["enpfr.config_ui"] = nil
    local reloaded = require("enpfr")
    reloaded.setup({ keymap = false })

    eq("codex", reloaded.get_config().backend)
  end)

  vim.fn.stdpath = original_stdpath
  vim.fn.delete(directory, "rf")
  package.loaded["enpfr"] = nil
  package.loaded["enpfr.config_ui"] = nil
  translator = require("enpfr")
  config_ui = require("enpfr.config_ui")
  translator.reset_settings()

  assert(ok, err)
end)

vim.fn.jobstart = REAL_JOBSTART
