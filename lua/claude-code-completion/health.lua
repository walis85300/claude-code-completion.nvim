local M = {}

function M.check()
  vim.health.start("claude-code-completion")

  local discovery = require("claude-code-completion.discovery")
  local has_blink = pcall(require, "blink.cmp")

  if has_blink then
    vim.health.ok("blink.cmp is available")
  else
    vim.health.warn("blink.cmp not found — using omnifunc fallback")
  end

  local claude_dir = discovery.get_claude_dir()
  local stat = vim.uv.fs_stat(claude_dir)
  if stat and stat.type == "directory" then
    vim.health.ok("~/.claude/ directory exists")
  else
    vim.health.warn("~/.claude/ directory not found")
  end

  local skills_dir = claude_dir .. "/skills"
  local skills_stat = vim.uv.fs_stat(skills_dir)
  if skills_stat and skills_stat.type == "directory" then
    local count = #vim.fn.glob(skills_dir .. "/*.md", false, true)
    vim.health.ok(("~/.claude/skills/ found (%d skill files)"):format(count))
  else
    vim.health.info("~/.claude/skills/ not found (no user skills)")
  end

  local scanner = require("claude-code-completion.scanner")
  local manifest_stat = vim.uv.fs_stat(scanner.get_manifest_path())
  if manifest_stat then
    vim.health.ok("SessionStart hook manifest found: " .. scanner.get_manifest_path())
  else
    vim.health.info("No SessionStart hook manifest — using filesystem scan fallback")
  end

  local agents = require("claude-code-completion.agents")
  local skill_count = #scanner.get_skills()
  local agent_count = #agents.get_agents()
  vim.health.ok(("Skills: %d | Agents: %d"):format(skill_count, agent_count))
end

return M
