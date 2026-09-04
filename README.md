# nvim-enpfr

Polish visually selected English text with Claude Code, Codex CLI, OpenCode,
or Antigravity CLI. The revised text appears in a read-only vertical split
while the original buffer remains unchanged and focused.

## Requirements

- Neovim 0.9 or newer
- At least one authenticated CLI on `PATH`:
  - `claude`
  - `codex`
  - `opencode`
  - `agy`

## Installation

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
        codex = "gpt-5.4",
        opencode = "openai/gpt-5.4",
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
        codex = "gpt-5.4",
        opencode = "openai/gpt-5.4",
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

## Configuration

```lua
require("enpfr").setup({
  -- Backend used when :EnPfr receives no backend argument.
  backend = "claude",

  -- A nil model lets that CLI use its configured default.
  models = {
    claude = "sonnet",
    codex = "gpt-5.4",
    opencode = "openai/gpt-5.4",
  },

  -- Visual-mode mapping. Use false to disable it.
  keymap = "<leader>ep",

  -- Resource limits for each request.
  max_input_bytes = 50000,
  max_output_bytes = 200000,
  timeout_ms = 120000,

  -- How long to wait for buffered stdout/stderr to finish after the backend
  -- process exits, before finalizing with whatever output was collected.
  exit_grace_ms = 200,
})
```

Model names are passed directly to the selected CLI. OpenCode model names must
use the `provider/model` form. Run `opencode models` to see the models currently
available to your account. Agy model names are passed directly to `agy --model`
(e.g. `gemini-3.8-flash-high`).

### Keymap reference

`keymap` only covers the visual-mode mapping created during `setup()`. If your
`init.lua` already reserves function keys for other plugins (e.g. `<F2>`-`<F7>`),
`<F8>` is a common next free slot:

```lua
use {
  "DrXiao/nvim-enpfr",
  config = function()
    require("enpfr").setup({
      keymap = "<F8>",
    })
  end,
}
```

This replaces the default `<leader>ep` visual-mode mapping with `<F8>`; select
text in visual mode first, then press `<F8>` to polish it. Setting `keymap = false`
disables the built-in mapping entirely if you'd rather define your own:

```lua
map('x', '<F8>', ':EnPfr<CR>')
```

## Usage

1. Select English text in characterwise, linewise, or blockwise visual mode.
2. Press `<leader>ep` to use the configured backend and model. If your
   `init.lua` never sets `vim.g.mapleader`, this defaults to `\ep`.
3. Compare the revised text in the read-only split on the right with the
   unchanged source on the left.

You can select a backend and model for an individual request from the visual
command line:

```vim
:EnPfr
:EnPfr claude opus
:EnPfr codex gpt-5.4
:EnPfr opencode openai/gpt-5.4
:EnPfr agy gemini-3.8-flash-high
```

Neovim automatically prefixes the command with the visual range, so it will
appear as `:'<,'>EnPfr ...`.

Cancel an active request with:

```vim
:EnPfrCancel
```

Starting another request also cancels the previous request. The existing
output window is reused within the current tab.

## Safety

- The plugin never writes to the source buffer.
- Selected text is sent over the process's standard input rather than exposed
  in shell commands or process arguments.
- Every backend runs from a private, empty temporary working directory.
- Claude runs in safe mode with no tools and without session persistence.
- Codex runs ephemerally in its read-only sandbox without user configuration
  or repository rules.
- OpenCode receives inline configuration that denies all tools and disables
  sharing and snapshots.
- Agy runs with `--sandbox` and without `--dangerously-skip-permissions`, so
  tool calls are refused by default.
- Backend failures and malformed output are displayed in the output buffer.

The selected text is sent to the configured AI provider and remains subject to
that provider's privacy policy and account limits. The CLIs may retain local
usage metadata or sessions according to their own storage policies; in
particular, OpenCode currently has no ephemeral `run` option.

Codex CLI does not expose a no-tools mode. Its read-only sandbox prevents file
changes, and the plugin isolates its working directory and ignores user and
repository instructions, but the model can still request read-only shell or
filesystem operations. Do not send untrusted or sensitive text through the
Codex backend if that residual access is unacceptable.

Agy CLI's default tool refusal is a policy-level "soft deny": the CLI refuses
the tool call and exits normally, but the model can still attempt one, and no
documented environment variable forces it to ignore a local
`~/.gemini/antigravity-cli/settings.json` that grants broader permissions. If
your machine's Agy configuration allows tools, that configuration takes
precedence over the plugin's flags. Review your Agy permission settings before
relying on this backend for untrusted or sensitive text.

## Tests

```sh
make test
```

The suite uses headless Neovim and does not make network requests.
