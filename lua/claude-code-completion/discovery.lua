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

--- Scan a directory for .md files (flat, nested SKILL.md, and category-nested layouts).
--- Returns { name, description } entries with caller-specified source.
--- @param dir string Absolute path to scan
--- @param source string Source tag ("user", "project", "plugin")
--- @param namespace string|nil Plugin name prefix (e.g. "compound-engineering")
--- @return { name: string, description: string, source: string }[]
function M.scan_dir(dir, source, namespace)
  local items = {}
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then
    return items
  end

  --- Prepend namespace to a name when present.
  local function qualify(name)
    return namespace and (namespace .. ":" .. name) or name
  end

  -- Flat: dir/*.md
  for _, filepath in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(filepath)
    if parsed then
      items[#items + 1] = { name = qualify(parsed.name), description = parsed.description, source = source }
    end
  end

  -- Nested: dir/<name>/SKILL.md — canonical name is the directory name, not frontmatter
  for _, skill_file in ipairs(vim.fn.glob(dir .. "/*/SKILL.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(skill_file)
    if parsed then
      local name = vim.fn.fnamemodify(skill_file, ":h:t")
      items[#items + 1] = { name = qualify(name), description = parsed.description, source = source }
    end
  end

  -- Category-nested: dir/<category>/<name>.md (agents use this layout)
  for _, filepath in ipairs(vim.fn.glob(dir .. "/*/*.md", false, true)) do
    if vim.fn.fnamemodify(filepath, ":t") ~= "SKILL.md" then
      local parsed = frontmatter.parse_skill_file(filepath)
      if parsed then
        local category = vim.fn.fnamemodify(filepath, ":h:t")
        items[#items + 1] = { name = qualify(category .. ":" .. parsed.name), description = parsed.description, source = source }
      end
    end
  end

  return items
end

--- Scan all plugin directories for a given subdir ("skills" or "agents").
--- Traverses both plugin cache and marketplace layouts.
--- Extracts plugin name from path and uses it as namespace prefix.
--- @param subdir string "skills" or "agents"
--- @return table[]
function M.scan_plugins(subdir)
  local claude_dir = M.get_claude_dir()
  local items = {}

  -- Cache layout: cache/{marketplace}/{plugin}/{version}/{subdir}
  for _, dir in ipairs(vim.fn.glob(claude_dir .. "/plugins/cache/*/*/*/" .. subdir, false, true)) do
    local plugin_name = vim.fn.fnamemodify(dir, ":h:h:t")
    vim.list_extend(items, M.scan_dir(dir, "plugin", plugin_name))
  end

  -- Marketplace layout: marketplaces/{marketplace}/plugins/{plugin}/{subdir}
  for _, dir in ipairs(vim.fn.glob(claude_dir .. "/plugins/marketplaces/*/plugins/*/" .. subdir, false, true)) do
    local plugin_name = vim.fn.fnamemodify(dir, ":h:t")
    vim.list_extend(items, M.scan_dir(dir, "plugin", plugin_name))
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
