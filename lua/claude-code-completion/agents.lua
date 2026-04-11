--- Agent discovery for @agent completion in Claude Code prompt buffers.
--- Discovers agents from built-in list, user/project dirs, and plugin dirs.
--- Same directory layout as skills but under `agents/` subdirectories.
local M = {}

local frontmatter = require("claude-code-completion.frontmatter")

--- @class claude_code.Agent
--- @field name string
--- @field description string
--- @field source "builtin"|"user"|"project"|"plugin"

--- @type claude_code.Agent[]
local BUILTIN_AGENTS = {
  { name = "general-purpose", description = "General-purpose agent for complex, multi-step tasks", source = "builtin" },
  { name = "Explore", description = "Fast agent for exploring codebases — find files, search code, answer questions", source = "builtin" },
  { name = "Plan", description = "Software architect agent for designing implementation plans", source = "builtin" },
  { name = "claude-code-guide", description = "Answer questions about Claude Code features, hooks, MCP, settings", source = "builtin" },
  { name = "statusline-setup", description = "Configure the Claude Code status line setting", source = "builtin" },
  { name = "code-review:security-reviewer", description = "Audit code for OWASP Top 10 vulnerabilities and security anti-patterns", source = "builtin" },
}

--- @type claude_code.Agent[]|nil
local cache = nil

--- Scan a directory for agent .md files (flat layout: dir/*.md).
--- @param dir string
--- @param source string
--- @return claude_code.Agent[]
local function scan_dir(dir, source)
  local agents = {}
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then
    return agents
  end

  for _, filepath in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(filepath)
    if parsed then
      agents[#agents + 1] = {
        name = parsed.name,
        description = parsed.description,
        source = source,
      }
    end
  end

  return agents
end

--- Get all discovered agents (cached).
--- @return claude_code.Agent[]
function M.get_agents()
  if cache then
    return cache
  end

  local home = vim.uv.os_homedir() or vim.fn.expand("~")
  local claude_dir = home .. "/.claude"
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  local agents = {}

  -- 1. Built-in agents
  vim.list_extend(agents, BUILTIN_AGENTS)

  -- 2. User agents
  vim.list_extend(agents, scan_dir(claude_dir .. "/agents", "user"))

  -- 3. Project agents
  vim.list_extend(agents, scan_dir(cwd .. "/.claude/agents", "project"))

  -- 4. Plugin agents (cache + marketplaces)
  local agent_dirs = vim.fn.glob(claude_dir .. "/plugins/cache/*/*/*/agents", false, true)
  vim.list_extend(agent_dirs, vim.fn.glob(claude_dir .. "/plugins/marketplaces/*/plugins/*/agents", false, true))
  for _, adir in ipairs(agent_dirs) do
    vim.list_extend(agents, scan_dir(adir, "plugin"))
  end

  -- Dedupe by name
  local seen = {}
  local unique = {}
  for _, a in ipairs(agents) do
    if not seen[a.name] then
      seen[a.name] = true
      unique[#unique + 1] = a
    end
  end

  cache = unique
  return cache
end

function M.refresh()
  cache = nil
end

return M
