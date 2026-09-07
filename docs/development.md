# Development

## Automated tests

```sh
make test
```

The suite uses headless Neovim and does not make network requests.

## Manual testing

```sh
make dev
```

Opens an interactive Neovim sandboxed to this checkout with a scratch buffer
of sample text already loaded, `<F8>` bound to polish a visual selection
(`:EnPfr`), and `<F9>` bound to `:EnPfrConfig`. Every request goes through
whichever real backend CLIs are installed and authenticated on your machine,
so this is the way to confirm a change actually behaves correctly end-to-end
rather than only passing the mocked unit tests. See `tests/dev_init.lua` if
you want to change the sample text or the bound keys for a given testing
session.

The `dev` target points `XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_STATE_HOME`/
`XDG_CACHE_HOME` at a fresh temp directory before launching Neovim. This
isolation is load-bearing, not cosmetic: without it, Neovim still discovers
and loads your real `~/.config/nvim` and `~/.local/share/nvim/site/pack/...`
*after* `tests/dev_init.lua` runs, and if you already have nvim-enpfr
installed for daily use, your plugin manager's compiled config for it
re-invokes `require("enpfr").setup({...your real settings...})` with no
knowledge of the sandbox — silently overwriting whatever `tests/dev_init.lua`
just configured (this is exactly what happened when a `config_keymap`
mapping worked in isolation but not through `nvim -u tests/dev_init.lua`
directly: the real config's own `setup()` call, having no `config_keymap` of
its own, deleted the sandbox's mapping and had nothing to put back). Always
use `make dev`, not a bare `nvim -u tests/dev_init.lua`, unless you've
independently confirmed you have no other nvim-enpfr install competing for
the same config.

The temp directory is removed automatically when Neovim exits, whether you
quit normally or interrupt it (`Ctrl-C`) — the `dev` target sets a shell
`trap ... EXIT` around the whole invocation, so nothing accumulates under
`/tmp` across repeated `make dev` runs.

See [IMPLEMENTATION.md](../IMPLEMENTATION.md) for the plugin's internal
architecture.
