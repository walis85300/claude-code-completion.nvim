--- Syntax highlighting for Claude Code prompt buffers.
--- Highlights /slash-commands and @mentions using matchadd.
local M = {}

local HL_GROUPS = {
  { name = "ClaudeSlashCommand", link = "@keyword" },
  { name = "ClaudeSlashNamespace", link = "@punctuation.delimiter" },
  { name = "ClaudeAtMention", link = "@attribute" },
}

local MATCH_PATTERNS = {
  { group = "ClaudeSlashCommand", pattern = [[\v(^|\s)\zs\/[a-zA-Z][a-zA-Z0-9:_-]*]] },
  { group = "ClaudeAtMention", pattern = [[\v(^|\s)\zs\@[a-zA-Z0-9_./-]+]] },
}

--- Define default highlight groups. Uses `default = true` so user overrides survive.
function M.define_groups()
  for _, hl in ipairs(HL_GROUPS) do
    vim.api.nvim_set_hl(0, hl.name, { default = true, link = hl.link })
  end
end

--- Apply match-based highlighting to the current window.
function M.apply_to_window()
  for _, m in ipairs(MATCH_PATTERNS) do
    vim.fn.matchadd(m.group, m.pattern, 10, -1, { window = 0 })
  end
end

--- Register highlight autocmds in the given augroup.
--- @param group number augroup id
function M.register(group)
  M.define_groups()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = M.define_groups,
  })
end

return M
