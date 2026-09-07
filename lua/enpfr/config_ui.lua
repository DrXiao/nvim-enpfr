local float_ui = require("enpfr.float_ui")

local M = {}

local function default_label(model_name)
  return model_name and (model_name .. " (default)") or "<CLI default>"
end

-- Builds the top-level menu asynchronously: every backend without a
-- configured model needs backends.default_model() to know what to show, and
-- for opencode that means an actual subprocess call. on_ready(entries) fires
-- once every backend's row is resolved, regardless of how many needed a
-- fetch or in what order they finish.
local function build_menu(on_ready)
  local enpfr = require("enpfr")
  local backends = require("enpfr.backends")
  local config = enpfr.get_config()
  local names = backends.names()

  local model_labels = {}
  local pending = 0
  -- Guards against a cache-hit backend resolving synchronously mid-loop and
  -- driving `pending` to 0 before every backend has even been registered
  -- (i.e. before the loop below has run for the remaining names). Finalize
  -- is only allowed to actually fire once registration has fully finished.
  local registering = true

  local function finalize()
    local entries = {
      { label = "Default backend: " .. config.backend, action = M.pick_backend },
    }
    for _, name in ipairs(names) do
      entries[#entries + 1] = {
        label = "Model for " .. name .. ": " .. model_labels[name],
        action = function()
          M.pick_model(name)
        end,
      }
    end
    entries[#entries + 1] = {
      label = "Reset all settings to defaults",
      action = function()
        enpfr.reset_settings()
        vim.notify("enpfr: settings reset to defaults", vim.log.levels.INFO)
        M.open()
      end,
    }
    entries[#entries + 1] = { label = "Close", action = function() end }
    on_ready(entries)
  end

  local function maybe_finalize()
    if not registering and pending == 0 then
      finalize()
    end
  end

  for _, name in ipairs(names) do
    local configured = config.models[name]
    if configured then
      model_labels[name] = configured
    else
      pending = pending + 1
      backends.default_model(name, function(model_name)
        model_labels[name] = default_label(model_name)
        pending = pending - 1
        maybe_finalize()
      end)
    end
  end
  registering = false

  maybe_finalize()
end

function M.open()
  build_menu(function(entries)
    local labels = vim.tbl_map(function(entry)
      return entry.label
    end, entries)

    float_ui.select(labels, { prompt = "EnPfr settings" }, function(_, index)
      if not index then
        return
      end
      entries[index].action()
    end)
  end)
end

function M.pick_backend()
  local backends = require("enpfr.backends")
  local enpfr = require("enpfr")
  float_ui.select(backends.names(), { prompt = "Default backend" }, function(choice)
    if choice then
      enpfr.set_backend(choice)
      vim.notify("enpfr: default backend set to " .. choice, vim.log.levels.INFO)
    end
    M.open()
  end)
end

function M.pick_model(backend_name)
  local backends = require("enpfr.backends")
  local enpfr = require("enpfr")

  backends.fetch_models(backend_name, function(models)
    backends.default_model(backend_name, function(default_model_name)
      local entries = {}
      for _, model in ipairs(models) do
        entries[#entries + 1] = {
          label = model,
          action = function()
            enpfr.set_model(backend_name, model)
            vim.notify("enpfr: " .. backend_name .. " model set to " .. model, vim.log.levels.INFO)
            M.open()
          end,
        }
      end
      entries[#entries + 1] = {
        label = "[Enter manually]",
        action = function()
          float_ui.input({ prompt = backend_name .. " model: " }, function(input)
            if input and input ~= "" then
              enpfr.set_model(backend_name, input)
              vim.notify("enpfr: " .. backend_name .. " model set to " .. input, vim.log.levels.INFO)
            end
            M.open()
          end)
        end,
      }
      entries[#entries + 1] = {
        label = "[Use CLI default] " .. default_label(default_model_name),
        action = function()
          enpfr.set_model(backend_name, nil)
          vim.notify("enpfr: " .. backend_name .. " model reset to CLI default", vim.log.levels.INFO)
          M.open()
        end,
      }

      local labels = vim.tbl_map(function(entry)
        return entry.label
      end, entries)

      float_ui.select(labels, { prompt = "Model for " .. backend_name }, function(_, index)
        if not index then
          M.open()
          return
        end
        entries[index].action()
      end)
    end)
  end)
end

return M
