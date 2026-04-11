NVIM := nvim --headless -u tests/minimal_init.lua

.PHONY: test test-frontmatter test-builtins test-init

test: test-frontmatter test-builtins test-init
	@echo "\nAll tests passed."

test-frontmatter:
	@$(NVIM) -l tests/test_frontmatter.lua

test-builtins:
	@$(NVIM) -l tests/test_builtins.lua

test-init:
	@$(NVIM) -l tests/test_init.lua
