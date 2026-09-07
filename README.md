# nvim-enpfr

Polish visually selected English text with Claude Code, Codex CLI, OpenCode,
or Antigravity CLI. The revised text appears in a read-only vertical split
while the original buffer remains unchanged and focused.

## Requirements

- Neovim 0.9 or newer
- At least one authenticated CLI on `PATH`: `claude`, `codex`, `opencode`, or `agy`

## Quick start

With lazy.nvim:

```lua
{
  "DrXiao/nvim-enpfr",
  config = function()
    require("enpfr").setup()
  end,
}
```

Select English text in visual mode and press `<leader>enpfr` (or `\enpfr` if
you never set `vim.g.mapleader`) to polish it.

## Documentation

- [Installation](docs/installation.md) — requirements and plugin-manager setup
- [Configuration](docs/configuration.md) — every `setup()` option, leaving
  `models` unset, and keymaps
- [Usage](docs/usage.md) — `:EnPfr`, `:EnPfrCancel`, and the `:EnPfrConfig`
  settings menu
- [Safety](docs/safety.md) — what each backend is and isn't restricted from
  doing while a request runs
- [Development](docs/development.md) — running the test suite and manually
  testing against real backend CLIs
- [IMPLEMENTATION.md](IMPLEMENTATION.md) — internal architecture
