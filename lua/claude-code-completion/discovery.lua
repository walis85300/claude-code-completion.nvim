--- Shared discovery logic for scanning Claude Code resource directories.
--- Used by both scanner.lua (skills) and agents.lua (agents).
--- Encapsulates: directory scanning, frontmatter parsing, plugin traversal,
--- path resolution, and deduplication.
local M = {}

local frontmatter = require("claude-code-completion.frontmatter")

--- @return string
function M.get_tmpdir()
  local tmpdir = vim.uv.os_getenv("TMPDIR")
  return (tmpdir and tmpdir ~= "") and tmpdir:gsub("/$", "") or "/tmp"
end

--- @return string
function M.get_claude_dir()
  return (vim.uv.os_homedir() or vim.fn.expand("~")) .. "/.claude"
end

--- @return string
function M.get_cwd()
  return vim.uv.cwd() or vim.fn.getcwd()
end

--- Remove duplicate entries by name, keeping the first occurrence.
--- @param items { name: string }[]
--- @return table[]
function M.dedupe(items)
  local seen = {}
  local result = {}
  for _, item in ipairs(items) do
    if not seen[item.name] then
      seen[item.name] = true
      result[#result + 1] = item
    end
  end
  return result
end

--- Scan a directory for .md files (flat + nested SKILL.md layout).
--- Returns { name, description } entries with caller-specified source.
--- @param dir string Absolute path to scan
--- @param source string Source tag ("user", "project", "plugin")
--- @return { name: string, description: string, source: string }[]
function M.scan_dir(dir, source)
  local items = {}
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then
    return items
  end

  -- Flat: dir/*.md
  for _, filepath in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(filepath)
    if parsed then
      items[#items + 1] = { name = parsed.name, description = parsed.description, source = source }
    end
  end

  -- Nested: dir/<name>/SKILL.md
  for _, skill_file in ipairs(vim.fn.glob(dir .. "/*/SKILL.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(skill_file)
    if parsed then
      local name = (parsed.name == "SKILL" or parsed.name == "") and vim.fn.fnamemodify(skill_file, ":h:t") or parsed.name
      items[#items + 1] = { name = name, description = parsed.description, source = source }
    end
  end

  return items
end

--- Scan all plugin directories for a given subdir ("skills" or "agents").
--- Traverses both plugin cache and marketplace layouts.
--- @param subdir string "skills" or "agents"
--- @return table[]
function M.scan_plugins(subdir)
  local claude_dir = M.get_claude_dir()
  local items = {}

  local dirs = vim.fn.glob(claude_dir .. "/plugins/cache/*/*/*/" .. subdir, false, true)
  vim.list_extend(dirs, vim.fn.glob(claude_dir .. "/plugins/marketplaces/*/plugins/*/" .. subdir, false, true))

  for _, dir in ipairs(dirs) do
    vim.list_extend(items, M.scan_dir(dir, "plugin"))
  end

  return items
end

--- Full scan of all directories for a given subdir.
--- Scans user, project, and plugin paths. Does NOT include builtins
--- (those are caller-specific).
--- @param subdir string "skills" or "agents"
--- @param opts { user: boolean, project: boolean, plugins: boolean }|nil
--- @return table[]
function M.scan_all(subdir, opts)
  opts = opts or { user = true, project = true, plugins = true }
  local claude_dir = M.get_claude_dir()
  local cwd = M.get_cwd()
  local items = {}

  if opts.user then
    vim.list_extend(items, M.scan_dir(claude_dir .. "/" .. subdir, "user"))
  end
  if opts.project then
    vim.list_extend(items, M.scan_dir(cwd .. "/.claude/" .. subdir, "project"))
  end
  if opts.plugins then
    vim.list_extend(items, M.scan_plugins(subdir))
  end

  return items
end

return M
