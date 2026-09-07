# Installation

## Requirements

- Neovim 0.9 or newer
- At least one authenticated CLI on `PATH`:
  - `claude`
  - `codex`
  - `opencode`
  - `agy`

## Installing the plugin

Install the plugin from `DrXiao/nvim-enpfr` with your plugin manager. For
example, with lazy.nvim:

```lua
{
  "DrXiao/nvim-enpfr",
  config = function()
    require("enpfr").setup({
      backend = "claude",
      models = {
        claude = "sonnet",
        codex = "gpt-5.6-terra",
        opencode = "openai/gpt-5.6-terra",
        agy = "gemini-3.8-flash-high",
      },
    })
  end,
}
```

With packer.nvim, add a `use` block to the `require('packer').startup(function(use) ... end)`
call in your `init.lua`:

```lua
use {
  "DrXiao/nvim-enpfr",
  config = function()
    require("enpfr").setup({
      backend = "claude",
      models = {
        claude = "sonnet",
        codex = "gpt-5.6-terra",
        opencode = "openai/gpt-5.6-terra",
        agy = "gemini-3.8-flash-high",
      },
    })
  end,
}
```

Without a plugin manager:

```sh
git clone https://github.com/DrXiao/nvim-enpfr.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/plugins/start/nvim-enpfr"
```

```lua
require("enpfr").setup()
```

See [Configuration](configuration.md) for every `setup()` option, and
[Usage](usage.md) for how to actually run a request once it's installed.
