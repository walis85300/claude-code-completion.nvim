--- Manifest generator — entry point for the SessionStart hook.
--- Called via: nvim --headless --clean --cmd "set rtp+=<plugin>" -l manifest.lua
--- Reads hook JSON from stdin, scans all skill sources, writes manifest to $TMPDIR.
--- Reuses the plugin's own discovery module — zero duplication.

local builtins = require("claude-code-completion.builtins")
local discovery = require("claude-code-completion.discovery")

-- --- Read CWD from hook stdin ---

local cwd = discovery.get_cwd()

local stdin = vim.uv.new_pipe()
stdin:open(0)
local stdin_data = ""
stdin:read_start(function(_, data)
  if data then
    stdin_data = stdin_data .. data
  else
    stdin:read_stop()
    stdin:close()
  end
end)

vim.defer_fn(function()
  if stdin_data ~= "" then
    local ok, input = pcall(vim.json.decode, stdin_data)
    if ok and input and input.cwd then
      cwd = input.cwd
    end
  end

  -- Scan skills using shared discovery (respects CWD override from hook)
  -- We can't use discovery.scan_all here because CWD may differ from vim's CWD
  local claude_dir = discovery.get_claude_dir()
  local skills = {}

  vim.list_extend(skills, builtins.get())
  vim.list_extend(skills, discovery.scan_dir(claude_dir .. "/skills", "user"))
  vim.list_extend(skills, discovery.scan_dir(cwd .. "/.claude/skills", "project"))
  vim.list_extend(skills, discovery.scan_plugins("skills"))

  local unique = discovery.dedupe(skills)

  -- Write manifest
  local tmpdir = discovery.get_tmpdir()
  local hash = vim.fn.sha256(cwd):sub(1, 12)
  local manifest_path = tmpdir .. "/claude-skills-" .. hash .. ".json"
  local latest_path = tmpdir .. "/claude-skills-latest.json"

  local content = vim.json.encode({
    version = 1,
    cwd = cwd,
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    skills = unique,
  })

  for _, path in ipairs({ manifest_path, latest_path }) do
    local f = io.open(path, "w")
    if f then
      f:write(content)
      f:close()
    end
  end

  vim.cmd("qa!")
end, 10)
