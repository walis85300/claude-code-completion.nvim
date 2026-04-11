--- Built-in Claude Code commands and bundled skills.
--- This list is a snapshot of user-facing commands; dynamic skills are
--- discovered at runtime via the scanner or SessionStart hook manifest.
local M = {}

--- @class claude_code.Skill
--- @field name string
--- @field description string
--- @field source "builtin"|"bundled"|"user"|"project"|"plugin"

--- @type claude_code.Skill[]
local builtins = {
  -- Built-in commands
  { name = "add-dir", description = "Add directories to context", source = "builtin" },
  { name = "clear", description = "Clear conversation history", source = "builtin" },
  { name = "color", description = "Change agent color", source = "builtin" },
  { name = "compact", description = "Compact conversation to save context", source = "builtin" },
  { name = "commit", description = "Create a git commit", source = "builtin" },
  { name = "commit-push-pr", description = "Commit, push, and create a PR", source = "builtin" },
  { name = "config", description = "View or modify configuration", source = "builtin" },
  { name = "context", description = "Manage context files", source = "builtin" },
  { name = "copy", description = "Copy last response to clipboard", source = "builtin" },
  { name = "cost", description = "Show session cost", source = "builtin" },
  { name = "desktop", description = "Open in desktop app", source = "builtin" },
  { name = "diff", description = "Show file differences", source = "builtin" },
  { name = "doctor", description = "Diagnose system issues", source = "builtin" },
  { name = "effort", description = "Set effort level", source = "builtin" },
  { name = "exit", description = "Exit Claude Code", source = "builtin" },
  { name = "fast", description = "Toggle fast mode", source = "builtin" },
  { name = "feedback", description = "Send feedback", source = "builtin" },
  { name = "files", description = "List tracked files", source = "builtin" },
  { name = "help", description = "Show help", source = "builtin" },
  { name = "hooks", description = "Manage hooks", source = "builtin" },
  { name = "ide", description = "IDE integration settings", source = "builtin" },
  { name = "init", description = "Initialize project configuration", source = "builtin" },
  { name = "install-github-app", description = "Install GitHub app integration", source = "builtin" },
  { name = "install-slack-app", description = "Install Slack app integration", source = "builtin" },
  { name = "keybindings", description = "Manage keyboard shortcuts", source = "builtin" },
  { name = "login", description = "Sign in to your account", source = "builtin" },
  { name = "logout", description = "Sign out", source = "builtin" },
  { name = "mcp", description = "Manage MCP servers", source = "builtin" },
  { name = "memory", description = "View and manage memory", source = "builtin" },
  { name = "model", description = "Select model", source = "builtin" },
  { name = "permissions", description = "Manage permissions", source = "builtin" },
  { name = "plan", description = "Toggle plan mode", source = "builtin" },
  { name = "plugin", description = "Manage plugins", source = "builtin" },
  { name = "pr-comments", description = "View PR comments", source = "builtin" },
  { name = "release-notes", description = "Show changelog", source = "builtin" },
  { name = "rename", description = "Rename session", source = "builtin" },
  { name = "resume", description = "Resume a previous session", source = "builtin" },
  { name = "review", description = "Code review", source = "builtin" },
  { name = "security-review", description = "Security-focused code review", source = "builtin" },
  { name = "session", description = "Session management", source = "builtin" },
  { name = "skills", description = "List available skills", source = "builtin" },
  { name = "status", description = "Show session status", source = "builtin" },
  { name = "statusline", description = "Toggle status line", source = "builtin" },
  { name = "tasks", description = "Manage background tasks", source = "builtin" },
  { name = "theme", description = "Change terminal theme", source = "builtin" },
  { name = "usage", description = "Show API usage", source = "builtin" },
  { name = "vim", description = "Toggle vim mode", source = "builtin" },

  -- Bundled skills
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
}

--- Return the list of built-in skills.
--- @return claude_code.Skill[]
function M.get()
  return builtins
end

return M
