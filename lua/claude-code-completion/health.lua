local M = {}

function M.check()
  vim.health.start("claude-code-completion")

  local has_blink = pcall(require, "blink.cmp")
  if has_blink then
    vim.health.ok("blink.cmp is available")
  else
    vim.health.warn("blink.cmp not found — using omnifunc fallback")
  end

  local claude_dir = (vim.uv.os_homedir() or vim.fn.expand("~")) .. "/.claude"
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
  local manifest_path = scanner.get_manifest_path()
  local manifest_stat = vim.uv.fs_stat(manifest_path)
  if manifest_stat then
    vim.health.ok("SessionStart hook manifest found: " .. manifest_path)
  else
    vim.health.info("No SessionStart hook manifest — using filesystem scan fallback")
  end

  local skills = scanner.get_skills()
  vim.health.ok(("Total skills discovered: %d"):format(#skills))
end

return M
