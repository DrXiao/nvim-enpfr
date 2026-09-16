# Usage

1. Select English text in characterwise, linewise, or blockwise visual mode.
2. Press `<leader>enpfr` to use the configured backend and model. If your
   `init.lua` never sets `vim.g.mapleader`, this defaults to `\enpfr`.
3. Compare the revised text in the read-only split on the right with the
   unchanged source on the left. Words the backend actually changed have
   their text recolored (`EnPfrDiffChanged`, linked to `DiagnosticWarn` by
   default) so you can spot at a glance what was wrong with your original
   wording. Override the highlight with your own
   `:highlight EnPfrDiffChanged ...` if you want a different color than your
   colorscheme's `DiagnosticWarn`.

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

The output split's status line always names the model in use, even if you
never configured one — `:EnPfr claude` with no configured model shows
"Polishing with claude (haiku)..." rather than leaving the model out.

## Modes

- **General** (the default) is the plain copy-editing behavior described
  above.
- **CS expert** does the same copy-editing pass, but with the model acting as
  a senior computer science expert (a senior software engineer, a senior
  embedded-systems engineer, or similar — not limited to any one specialty).
  When at least one edit reflects that expertise (technical terminology, a
  naming convention, a technically inaccurate statement, and the like), it
  adds a "Why this was changed:" section below the revised text, as a
  bulleted list covering only those CS-specific reasons. A request whose
  only changes are plain grammar/style fixes with no CS-specific reasoning
  gets no explanation section at all. That section, when present, is plain
  prose and is never diff-highlighted itself — only the revised text above
  it is.

`:EnPfr` and `keymap` always use the configured default mode (`mode` in
`setup()`, or whatever the [settings menu](#settings-menu) last saved). There
is no per-request mode override — set the default mode there before running
`:EnPfr` if you want to switch modes for a request.

Cancel an active request with:

```vim
:EnPfrCancel
```

Starting another request also cancels the previous request. The existing
output window is reused within the current tab.

## Settings menu

Run `:EnPfrConfig`, or press the key set in `config_keymap` (e.g. `<F9>`),
to open a centered floating-window menu for setting the default mode
([general or CS expert](#modes)), the default backend, each backend's
default model, and picking a model from a list instead of typing one from
memory. Divider lines group the menu into three sections in order: the
default mode, the backend/model settings, and the reset/close actions at
the bottom. Move with `j`/`k` or the
arrow keys, `<CR>` to confirm the highlighted line, and `q`/`<Esc>` to cancel
and go back. Model listing is live for `opencode` (`opencode models`) and
`agy` (`agy models`); `claude` and `codex` currently expose no such
subcommand, so their pickers fall back to a small, best-effort static list
that can drift from what your account actually has access to — use "[Enter
manually]" (a floating text input, also confirmed with `<CR>` and cancelled
with `<Esc>`) if the model you want isn't listed.

Every backend row shows the model it will actually use — either the model
you configured, or, if none is configured, an assumed default named as
`<model-name> (default)` (e.g. `haiku (default)`). This assumed default is
a display hint, not something the plugin passes as `--model`; see
[Leaving `models` unset](configuration.md#leaving-models-unset) for where
each backend's assumed name comes from (`agy`'s is the one case not derived
from its own `agy models` output — that command has no field marking any
entry as the account's actual default). The model picker's "[Use CLI
default]" entry shows the same assumed name and clears your configured model
back to it.

Changes made through this menu are written to
`stdpath("data")/enpfr_settings.json` and are loaded again the next time
`setup()` runs, so they survive restarting Neovim. If your own config's
`setup({...})` call explicitly sets `mode`, `backend`, or a `models` entry,
that explicit value always wins over whatever the menu last saved. Use "Reset all
settings to defaults" in the menu to delete the persisted file and go back to
the plugin's built-in defaults.

See [Safety](safety.md) for what each backend is and isn't restricted from
doing while a request runs.
