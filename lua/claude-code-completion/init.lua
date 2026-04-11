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

-- Re-export buffer utilities for consumers.

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
        require("claude-code-completion.agents").refresh()
        last_refresh = now
      end

      if not pcall(require, "blink.cmp") then
        vim.bo[ev.buf].omnifunc = "v:lua.require'claude-code-completion'.omnifunc"
      end

      highlight.apply(ev.buf)

      -- Live semantic highlighting as you type
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = ev.buf,
        callback = function()
          highlight.apply(ev.buf)
        end,
      })

      -- Buffer-local keymaps for the picker
      local picker = require("claude-code-completion.picker")
      vim.keymap.set("n", "<leader>/", picker.skills, { buffer = ev.buf, desc = "Claude: browse skills" })
      vim.keymap.set("n", "<leader>@", picker.mentions, { buffer = ev.buf, desc = "Claude: browse files/agents" })
      vim.keymap.set("n", "<leader>cp", function() picker.open() end, { buffer = ev.buf, desc = "Claude: browse all" })
      vim.keymap.set("i", "<C-/>", picker.skills, { buffer = ev.buf, desc = "Claude: browse skills" })
      vim.keymap.set("i", "<C-@>", picker.mentions, { buffer = ev.buf, desc = "Claude: browse files/agents" })
    end,
  })

  -- Global commands
  vim.api.nvim_create_user_command("ClaudeSkillsRefresh", function()
    local scanner = require("claude-code-completion.scanner")
    local agents = require("claude-code-completion.agents")
    scanner.refresh()
    agents.refresh()
    vim.notify(("Claude Code: refreshed %d skills, %d agents"):format(
      #scanner.get_skills(), #agents.get_agents()), vim.log.levels.INFO)
  end, { desc = "Refresh Claude Code skills and agents cache" })

  vim.api.nvim_create_user_command("ClaudePicker", function(cmd)
    require("claude-code-completion.picker").open(cmd.args ~= "" and cmd.args or nil)
  end, { nargs = "?", desc = "Open Claude Code picker (skills, agents, files)" })
end

--- @private
function M._reset()
  setup_done = false
  config = defaults
end

return M
