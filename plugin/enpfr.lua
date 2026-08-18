if vim.g.loaded_enpfr then
  return
end
vim.g.loaded_enpfr = true

local translator = require("enpfr")
if not translator.is_configured() then
  translator.setup()
end
