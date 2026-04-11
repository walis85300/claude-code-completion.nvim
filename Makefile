NVIM := nvim --headless -u tests/minimal_init.lua

.PHONY: test test-frontmatter test-builtins test-init test-dedupe test-files test-agents test-highlight test-picker

test: test-frontmatter test-builtins test-init test-dedupe test-files test-agents test-highlight test-picker
	@echo "\nAll tests passed."

test-frontmatter:
	@$(NVIM) -l tests/test_frontmatter.lua

test-builtins:
	@$(NVIM) -l tests/test_builtins.lua

test-init:
	@$(NVIM) -l tests/test_init.lua

test-dedupe:
	@$(NVIM) -l tests/test_dedupe.lua

test-files:
	@$(NVIM) -l tests/test_files.lua

test-agents:
	@$(NVIM) -l tests/test_agents.lua

test-highlight:
	@$(NVIM) -l tests/test_highlight.lua

test-picker:
	@$(NVIM) -l tests/test_picker.lua
