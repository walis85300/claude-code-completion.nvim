--- claude-code-completion.nvim
--- Autocomplete for Claude Code skills/slash commands in the Ctrl+G editor.
local M = {}

--- @class claude_code.Config
--- @field scan_paths { user: boolean, project: boolean, plugins: boolean }

--- @type claude_code.Config
local defaults = {
  scan_paths = {
    user = true,
    project = true,
    plugins = true,
  },
}

--- @type claude_code.Config
local config = defaults
local setup_done = false

--- @return claude_code.Config
function M.get_config()
  return config
end

-- Re-export buffer utilities so consumers use a single require path.
-- Avoids breaking source.lua and external code that calls these.

--- @param bufnr number|nil
--- @return boolean
function M.is_claude_buffer(bufnr)
  return require("claude-code-completion.buffer").is_claude_buffer(bufnr)
end

--- @param line string
--- @param col number
--- @return number|nil
function M.find_slash_col(line, col)
  return require("claude-code-completion.buffer").find_slash_col(line, col)
end

--- Omnifunc entry point (called by vim via v:lua).
--- @param findstart number
--- @param base string
--- @return number|table
function M.omnifunc(findstart, base)
  return require("claude-code-completion.omnifunc").complete(findstart, base)
end

--- Set up the plugin.
--- @param opts claude_code.Config|nil
function M.setup(opts)
  if setup_done then
    return
  end
  setup_done = true

  config = vim.tbl_deep_extend("force", defaults, opts or {})

  local buffer = require("claude-code-completion.buffer")
  local highlight = require("claude-code-completion.highlight")

  local group = vim.api.nvim_create_augroup("ClaudeCodeCompletion", { clear = true })
  local last_refresh = 0
  local REFRESH_TTL_SEC = 5

  highlight.register(group)

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function(ev)
      if not buffer.is_claude_buffer(ev.buf) then
        return
      end

      local now = vim.uv.now() / 1000
      if (now - last_refresh) > REFRESH_TTL_SEC then
        require("claude-code-completion.scanner").refresh()
        last_refresh = now
      end

      if not pcall(require, "blink.cmp") then
        vim.bo[ev.buf].omnifunc = "v:lua.require'claude-code-completion'.omnifunc"
      end

      highlight.apply_to_window()
    end,
  })

  vim.api.nvim_create_user_command("ClaudeSkillsRefresh", function()
    local scanner = require("claude-code-completion.scanner")
    scanner.refresh()
    vim.notify(("Claude Code: refreshed %d skills"):format(#scanner.get_skills()), vim.log.levels.INFO)
  end, { desc = "Refresh Claude Code skills cache" })
end

--- @private
function M._reset()
  setup_done = false
  config = defaults
end

return M
