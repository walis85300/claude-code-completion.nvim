local M = {}

function M.check()
  vim.health.start("claude-code-completion")

  -- Check blink.cmp
  local has_blink = pcall(require, "blink.cmp")
  if has_blink then
    vim.health.ok("blink.cmp is available")
  else
    vim.health.warn("blink.cmp not found — using omnifunc fallback")
  end

  -- Check skill directories
  local home = vim.fn.expand("~")
  local claude_dir = home .. "/.claude"

  if vim.fn.isdirectory(claude_dir) == 1 then
    vim.health.ok("~/.claude/ directory exists")
  else
    vim.health.warn("~/.claude/ directory not found")
  end

  local skills_dir = claude_dir .. "/skills"
  if vim.fn.isdirectory(skills_dir) == 1 then
    local count = #vim.fn.glob(skills_dir .. "/*.md", false, true)
    vim.health.ok(string.format("~/.claude/skills/ found (%d skill files)", count))
  else
    vim.health.info("~/.claude/skills/ not found (no user skills)")
  end

  -- Check manifest
  local scanner = require("claude-code-completion.scanner")
  local manifest_path = scanner.get_manifest_path()
  if manifest_path and vim.fn.filereadable(manifest_path) == 1 then
    vim.health.ok("SessionStart hook manifest found: " .. manifest_path)
  else
    vim.health.info("No SessionStart hook manifest — using filesystem scan fallback")
  end

  -- Check bun (for the hook script)
  if vim.fn.executable("bun") == 1 then
    vim.health.ok("bun is available (for claude-skills-manifest hook)")
  else
    vim.health.info("bun not found — hook script requires bun to run")
  end

  -- Try a scan
  local skills = scanner.get_skills()
  vim.health.ok(string.format("Total skills discovered: %d", #skills))
end

return M
