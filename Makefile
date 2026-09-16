.PHONY: test dev

test:
	nvim --headless -u tests/minimal_init.lua -l tests/run.lua

dev:
	dev_home="$$(mktemp -d)"; \
	trap 'rm -rf "$$dev_home"' EXIT; \
	mkdir -p "$$dev_home/config" "$$dev_home/data" "$$dev_home/state" "$$dev_home/cache"; \
	XDG_CONFIG_HOME="$$dev_home/config" \
	XDG_DATA_HOME="$$dev_home/data" \
	XDG_STATE_HOME="$$dev_home/state" \
	XDG_CACHE_HOME="$$dev_home/cache" \
	nvim -u tests/dev_init.lua
