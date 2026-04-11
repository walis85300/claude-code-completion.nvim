--- Agent discovery for @agent completion in Claude Code prompt buffers.
local M = {}

local discovery = require("claude-code-completion.discovery")

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

--- @return claude_code.Agent[]
function M.get_agents()
  if cache then
    return cache
  end

  local agents = {}
  vim.list_extend(agents, BUILTIN_AGENTS)
  vim.list_extend(agents, discovery.scan_all("agents"))

  cache = discovery.dedupe(agents)
  return cache
end

function M.refresh()
  cache = nil
end

return M
