local failures = 0
local tests = 0

local function inspect(value)
  return vim.inspect(value)
end

function _G.test(name, callback)
  tests = tests + 1
  local ok, err = pcall(callback)
  if ok then
    print("ok - " .. name)
    return
  end

  failures = failures + 1
  print("not ok - " .. name)
  print(err)
end

function _G.eq(expected, actual)
  if not vim.deep_equal(expected, actual) then
    error("expected " .. inspect(expected) .. ", got " .. inspect(actual), 2)
  end
end

dofile("tests/selection_spec.lua")
dofile("tests/backends_spec.lua")
dofile("tests/float_ui_spec.lua")
dofile("tests/config_ui_spec.lua")
dofile("tests/prompt_spec.lua")
dofile("tests/output_spec.lua")
dofile("tests/plugin_spec.lua")

print(string.format("%d tests, %d failures", tests, failures))
if failures > 0 then
  vim.cmd("cquit " .. failures)
end

vim.cmd("quit")
