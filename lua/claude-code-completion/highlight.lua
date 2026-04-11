--- Semantic highlighting for Claude Code prompt buffers.
--- Only highlights KNOWN skills and agents — unrecognized /commands stay plain.
local M = {}

local ns = vim.api.nvim_create_namespace("claude_code_hl")

local HL_GROUPS = {
  { name = "ClaudeSlashCommand", link = "@keyword" },
  { name = "ClaudeSlashUnknown", link = "Comment" },
  { name = "ClaudeAtAgent", link = "@attribute" },
  { name = "ClaudeAtFile", link = "@string" },
  { name = "ClaudeAtUnknown", link = "Comment" },
}

--- Define default highlight groups. Uses `default = true` so user overrides survive.
function M.define_groups()
  for _, hl in ipairs(HL_GROUPS) do
    vim.api.nvim_set_hl(0, hl.name, { default = true, link = hl.link })
  end
end

--- Build a set of known names for fast lookup.
--- @return table<string, true> skills, table<string, true> agents
local function build_known_sets()
  local scanner = require("claude-code-completion.scanner")
  local agents_mod = require("claude-code-completion.agents")

  local skill_set = {}
  for _, s in ipairs(scanner.get_skills()) do
    skill_set[s.name] = true
  end

  local agent_set = {}
  for _, a in ipairs(agents_mod.get_agents()) do
    agent_set[a.name] = true
  end

  return skill_set, agent_set
end

--- Apply semantic highlights to the current buffer.
--- Called on BufEnter and on TextChanged/TextChangedI for live feedback.
function M.apply(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local skill_set, agent_set = build_known_sets()

  for i, line in ipairs(lines) do
    local row = i - 1

    -- Find /commands: at line start or after whitespace
    for start_pos, name in line:gmatch("()(/[%w:_-]+)") do
      local col = start_pos - 1
      -- Verify it's at line start or after whitespace
      if col == 0 or line:sub(col, col):match("%s") then
        local skill_name = name:sub(2) -- strip leading /
        local hl_group = skill_set[skill_name] and "ClaudeSlashCommand" or "ClaudeSlashUnknown"
        vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, row, col, col + #name)
      end
    end

    -- Find @mentions: at line start or after whitespace
    for start_pos, name in line:gmatch("()(@[%w_./:%-]+)") do
      local col = start_pos - 1
      if col == 0 or line:sub(col, col):match("%s") then
        local mention_name = name:sub(2) -- strip leading @
        local hl_group
        if agent_set[mention_name] then
          hl_group = "ClaudeAtAgent"
        elseif vim.uv.fs_stat((vim.uv.cwd() or "") .. "/" .. mention_name) then
          hl_group = "ClaudeAtFile"
        else
          hl_group = "ClaudeAtUnknown"
        end
        vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, row, col, col + #name)
      end
    end
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
