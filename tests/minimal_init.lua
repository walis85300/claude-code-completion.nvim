-- Minimal init for headless test runs.
-- Adds the plugin to runtimepath so require() finds our modules.
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_root)
