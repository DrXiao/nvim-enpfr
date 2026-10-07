.PHONY: test dev

test:
	nvim --headless -u tests/minimal_init.lua -l tests/run.lua

# The `dev` sandbox points the XDG_* dirs at a fresh temp directory so that
# tests/dev_init.lua is the only nvim-enpfr configuration in play. That same
# isolation would also hide the real OpenCode installation from the plugin:
# the opencode CLI keeps its credentials in its database and finds the shared
# model-listing service through a registration file in the state directory,
# both under the (now sandboxed) XDG dirs. OPENCODE_CONFIG_DIR and
# OPENCODE_DB are read by the opencode CLI only (Neovim ignores them), so
# pointing them back at the real dirs — and seeding the sandboxed state dir
# with a copy of the real service registration — lets `make dev` exercise
# the opencode backend with real credentials and a real `opencode models`
# list just like normal usage.
dev:
	dev_home="$$(mktemp -d)"; \
	trap 'rm -rf "$$dev_home"' EXIT; \
	mkdir -p "$$dev_home/config" "$$dev_home/data" "$$dev_home/state" "$$dev_home/cache" "$$dev_home/state/opencode"; \
	oc_cfg="$${OPENCODE_CONFIG_DIR:-$${XDG_CONFIG_HOME:-$$HOME/.config}/opencode}"; \
	oc_db="$${XDG_DATA_HOME:-$$HOME/.local/share}/opencode/opencode.db"; \
	oc_state="$${XDG_STATE_HOME:-$$HOME/.local/state}/opencode"; \
	if [ -f "$$oc_state/service.json" ]; then \
		cp "$$oc_state/service.json" "$$dev_home/state/opencode/service.json"; \
	fi; \
	XDG_CONFIG_HOME="$$dev_home/config" \
	XDG_DATA_HOME="$$dev_home/data" \
	XDG_STATE_HOME="$$dev_home/state" \
	XDG_CACHE_HOME="$$dev_home/cache" \
	OPENCODE_CONFIG_DIR="$$oc_cfg" \
	OPENCODE_DB="$$oc_db" \
	nvim -u tests/dev_init.lua
