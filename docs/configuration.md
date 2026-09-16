# Configuration

```lua
require("enpfr").setup({
  -- Backend used when :EnPfr receives no backend argument.
  backend = "claude",

  -- A nil model lets that CLI use its configured default.
  models = {
    claude = "sonnet",
    codex = "gpt-5.6-terra",
    opencode = "openai/gpt-5.6-terra",
    agy = "gemini-3.8-flash-high",
  },

  -- Default mode used by :EnPfr / keymap: "general" (plain copy-editing) or
  -- "cs_expert" (adds a "why this was changed" explanation from a senior
  -- CS expert's perspective). Changeable from :EnPfrConfig too. See
  -- docs/usage.md#modes.
  mode = "general",

  -- Visual-mode mapping. Use false to disable it.
  keymap = "<leader>enpfr",

  -- Normal-mode mapping that opens :EnPfrConfig. Unset (nil) by default;
  -- set to a key like "<F9>" to enable it.
  config_keymap = "<F9>",

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
use the `provider/model` form; Agy model names are passed directly to
`agy --model` (e.g. `gemini-3.8-flash-high`).

## Leaving `models` unset

`models` — and each entry inside it — is optional. Leave a backend out (or
skip `models` entirely) and no `--model` flag is passed at all, so that
backend's own CLI default is used. The plugin still needs *some* name to
show in the [`:EnPfrConfig` menu](usage.md#settings-menu) and the "Polishing
with ..." status line when nothing is configured, and where that name comes
from differs by backend:

- `claude` and `codex` expose no command to query their available models, so
  the plugin falls back to a small list built into the plugin itself
  (`known_models` in `lua/enpfr/backends.lua`) and shows its first entry —
  `haiku` for claude, `gpt-5.6-luna` for codex.
- `opencode` and `agy` do expose a listing command (`opencode models` /
  `agy models`), and the plugin runs it to populate the model picker. For
  `opencode`, the assumed default shown is likewise the first model that
  command returns. `agy` is the one exception: nothing in `agy models`'
  output marks any entry as the account's actual default, so treating
  "whatever line comes first" as meaningful would be arbitrary — the plugin
  shows a fixed fallback name (`gemini-3.8-flash-medium`) for `agy` instead.

None of this is authoritative or passed as `--model`; it exists only to
label the UI. Use "[Enter manually]" in the model picker, or set the model
explicitly in `models`, whenever the shown name isn't what you actually want.

## Keymap reference

`keymap` covers the visual-mode mapping created during `setup()`;
`config_keymap` covers the normal-mode mapping that opens `:EnPfrConfig`
(unset by default — set it to enable the mapping). If your `init.lua`
already reserves function keys for other plugins (e.g. `<F2>`-`<F7>`),
`<F8>`/`<F9>` are common next free slots:

```lua
use {
  "DrXiao/nvim-enpfr",
  config = function()
    require("enpfr").setup({
      keymap = "<F8>",
      config_keymap = "<F9>",
    })
  end,
}
```

This replaces the default `<leader>enpfr` visual-mode mapping with `<F8>`; select
text in visual mode first, then press `<F8>` to polish it. Pressing `<F9>` in
normal mode opens the settings menu. Setting `keymap = false` (or leaving
`config_keymap` unset) disables the corresponding built-in mapping entirely
if you'd rather define your own:

```lua
map('x', '<F8>', ':EnPfr<CR>')
map('n', '<F9>', ':EnPfrConfig<CR>')
```

See [Usage](usage.md) for what each mapping/command actually does.
