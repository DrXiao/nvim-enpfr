-- Throwaway interactive sandbox for manually exercising nvim-enpfr against
-- the real backend CLIs. Run via `make dev`, not directly: the Makefile
-- target sets XDG_CONFIG_HOME/XDG_DATA_HOME/etc. to a fresh temp directory
-- before launching Neovim, so this file is the ONLY nvim-enpfr
-- configuration in play. Without that env isolation, Neovim still
-- auto-loads plugin/ files from your real ~/.config/nvim and
-- ~/.local/share/nvim/site/pack/... (including a real, globally installed
-- copy of nvim-enpfr, if you have one, and your plugin manager's compiled
-- config for it) *after* this file runs, and its config = function() ...
-- require('enpfr').setup({...}) end silently re-runs setup() with your real
-- settings, clobbering whatever this sandbox configured (this is exactly
-- what caused an earlier version of this file to have a working
-- :EnPfrConfig command but a non-functional config_keymap: the real setup()
-- call, with no config_keymap of its own, deleted the sandbox's mapping and
-- had nothing to put back in its place).
vim.opt.runtimepath:prepend(vim.fn.getcwd())

require("enpfr").setup({
  keymap = "<F8>",
  config_keymap = "<F9>",
})

vim.cmd("enew")
vim.bo.buftype = ""
vim.bo.filetype = "markdown"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "## Usage Guide",
  "- Use visual mode to select text.",
  "- Press <F8> to perform proofreading on the selected text.",
  "- Press <F9> to open the settings menu",
  "  - default mode",
  "  - AI backend configuration",
  "    - default backend (e.g.: Claude Code, Codex, OpenCode, Antigravity)",
  "    - default model for each backend",
  "  - Press <Esc> to go back to the previous menu or exit the settings menu.",
  "",
  "",
  "## Test case 1",
  "### Guide",
  "- Directly select the text below in visual mode and press <F8> to perform",
  "  proofreading.",
  "- [Optional] Press <F9> to select the default backend and model for the",
  "  proofreading task.",
  "",
  "### Text",
  "This are a sentence with an error, select me in visual mode and press <F8>.",
  "",
  "",
  "## Test case 2",
  "### Guide",
  "- Press <F9> to select \"CS expert\" mode, then select the text below in visual",
  "  mode and press <F8> to perform proofreading.",
  "- [Optional] Press <F9> to select the default backend and model for the",
  "  proofreading task.",
  "",
  "### Text",
  "When multiple thread access a shared variable without no synchronization,",
  "a race condition can occur, and using a mutex lock help prevent this issue.",
  "The call back function registered for the interrupt handler also need to",
  "be re-entrant so it don't corrupt the buffer while running on an embedded",
  "system with limited memory, and it must not let the fire wall block a",
  "retry packet that the driver is waiting for.",
})

vim.notify(
  "enpfr dev sandbox: select text in visual mode + <F8> to polish, <F9> for :EnPfrConfig. "
    .. "Settings persist only to " .. vim.fn.stdpath("data"),
  vim.log.levels.INFO
)
