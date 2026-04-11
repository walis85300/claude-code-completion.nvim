--- Bundled Claude Code skills that make sense as prompt input.
---
--- This list only includes skills that expand into instructions for Claude
--- when typed in the Ctrl+G editor. Interactive CLI commands (/exit, /login,
--- /theme, etc.) are excluded — they control the CLI, not the prompt.
---
--- Dynamic skills from user, project, and plugin directories are discovered
--- at runtime via the scanner or SessionStart hook manifest.
local M = {}

--- @class claude_code.Skill
--- @field name string
--- @field description string
--- @field source "builtin"|"bundled"|"user"|"project"|"plugin"

--- @type claude_code.Skill[]
local skills = {
  -- Prompt-expanding skills (bundled with Claude Code)
  { name = "simplify", description = "Review changed code for quality and fix issues", source = "bundled" },
  { name = "debug", description = "Debug and diagnose issues", source = "bundled" },
  { name = "verify", description = "Verify content accuracy", source = "bundled" },
  { name = "remember", description = "Save information to memory", source = "bundled" },
  { name = "batch", description = "Run operations in batch", source = "bundled" },
  { name = "stuck", description = "Get help when stuck", source = "bundled" },
  { name = "skillify", description = "Convert instructions to a reusable skill", source = "bundled" },
  { name = "loop", description = "Run a command on a recurring interval", source = "bundled" },
  { name = "schedule", description = "Schedule remote agent triggers", source = "bundled" },
  { name = "claude-api", description = "Build apps with the Claude API", source = "bundled" },
  { name = "update-config", description = "Update Claude Code configuration", source = "bundled" },

  -- Built-in commands useful as prompt input
  { name = "commit", description = "Create a git commit", source = "builtin" },
  { name = "commit-push-pr", description = "Commit, push, and create a PR", source = "builtin" },
  { name = "review", description = "Code review", source = "builtin" },
  { name = "security-review", description = "Security-focused code review", source = "builtin" },
  { name = "compact", description = "Compact conversation to save context", source = "builtin" },
  { name = "init", description = "Initialize project configuration", source = "builtin" },
}

--- @return claude_code.Skill[]
function M.get()
  return skills
end

return M
