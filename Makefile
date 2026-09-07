.PHONY: test dev

test:
	nvim --headless -u tests/minimal_init.lua -l tests/run.lua

DEV_HOME := $(shell mktemp -d)

dev:
	trap 'rm -rf "$(DEV_HOME)"' EXIT; \
	mkdir -p "$(DEV_HOME)/config" "$(DEV_HOME)/data" "$(DEV_HOME)/state" "$(DEV_HOME)/cache"; \
	XDG_CONFIG_HOME="$(DEV_HOME)/config" \
	XDG_DATA_HOME="$(DEV_HOME)/data" \
	XDG_STATE_HOME="$(DEV_HOME)/state" \
	XDG_CACHE_HOME="$(DEV_HOME)/cache" \
	nvim -u tests/dev_init.lua
