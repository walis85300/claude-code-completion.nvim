--- Skill discovery: reads SessionStart hook manifest or falls back to filesystem scan.
local M = {}

local frontmatter = require("claude-code-completion.frontmatter")
local builtins = require("claude-code-completion.builtins")

--- @type claude_code.Skill[]|nil
local cache = nil

--- Get the manifest path for the current project CWD.
--- @return string|nil
function M.get_manifest_path()
  local cwd = vim.fn.getcwd()
  local hash = vim.fn.sha256(cwd):sub(1, 12)
  local tmpdir = vim.fn.getenv("TMPDIR")
  if not tmpdir or tmpdir == "" or tmpdir == vim.NIL then
    tmpdir = "/tmp"
  end
  return tmpdir .. "/claude-skills-" .. hash .. ".json"
end

--- Try to read the manifest written by the SessionStart hook.
--- @return claude_code.Skill[]|nil
local function read_manifest()
  -- Try project-specific manifest first
  local manifest_path = M.get_manifest_path()
  if not manifest_path then
    return nil
  end

  -- Also check the "latest" manifest as fallback
  local tmpdir = vim.fn.getenv("TMPDIR")
  if not tmpdir or tmpdir == "" or tmpdir == vim.NIL then
    tmpdir = "/tmp"
  end
  local latest_path = tmpdir .. "/claude-skills-latest.json"

  for _, path in ipairs({ manifest_path, latest_path }) do
    if vim.fn.filereadable(path) == 1 then
      local f = io.open(path, "r")
      if f then
        local content = f:read("*a")
        f:close()
        local ok, data = pcall(vim.json.decode, content)
        if ok and data and data.skills then
          --- @type claude_code.Skill[]
          local skills = {}
          for _, s in ipairs(data.skills) do
            table.insert(skills, {
              name = s.name,
              description = s.description or "",
              source = s.source or "plugin",
            })
          end
          return skills
        end
      end
    end
  end

  return nil
end

--- Scan a directory for skill .md files.
--- Handles two layouts:
---   1. Flat: dir/*.md (user/project skills)
---   2. Nested: dir/<name>/SKILL.md (plugin skills)
--- @param dir string
--- @param source string
--- @return claude_code.Skill[]
local function scan_dir(dir, source)
  local skills = {}
  if vim.fn.isdirectory(dir) ~= 1 then
    return skills
  end

  -- Flat: dir/*.md
  local md_files = vim.fn.glob(dir .. "/*.md", false, true)
  for _, filepath in ipairs(md_files) do
    local skill = frontmatter.parse_skill_file(filepath)
    if skill then
      skill.source = source
      table.insert(skills, skill)
    end
  end

  -- Nested: dir/<name>/SKILL.md
  local subdirs = vim.fn.glob(dir .. "/*/SKILL.md", false, true)
  for _, skill_file in ipairs(subdirs) do
    local skill = frontmatter.parse_skill_file(skill_file)
    if skill then
      -- Use parent directory name as fallback name
      if not skill.name or skill.name == "SKILL" then
        skill.name = vim.fn.fnamemodify(skill_file, ":h:t")
      end
      skill.source = source
      table.insert(skills, skill)
    end
  end

  return skills
end

--- Scan all plugin skill directories.
--- @param claude_dir string
--- @return claude_code.Skill[]
local function scan_plugins(claude_dir)
  local skills = {}

  -- Plugin cache: ~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/skills/
  local cache_dir = claude_dir .. "/plugins/cache"
  if vim.fn.isdirectory(cache_dir) == 1 then
    local marketplaces = vim.fn.glob(cache_dir .. "/*", false, true)
    for _, mdir in ipairs(marketplaces) do
      if vim.fn.isdirectory(mdir) == 1 then
        local plugins = vim.fn.glob(mdir .. "/*", false, true)
        for _, pdir in ipairs(plugins) do
          if vim.fn.isdirectory(pdir) == 1 then
            local versions = vim.fn.glob(pdir .. "/*", false, true)
            for _, vdir in ipairs(versions) do
              local sdir = vdir .. "/skills"
              for _, s in ipairs(scan_dir(sdir, "plugin")) do
                table.insert(skills, s)
              end
            end
          end
        end
      end
    end
  end

  -- Marketplace plugins: ~/.claude/plugins/marketplaces/*/plugins/*/skills/
  local mp_dir = claude_dir .. "/plugins/marketplaces"
  if vim.fn.isdirectory(mp_dir) == 1 then
    local marketplaces = vim.fn.glob(mp_dir .. "/*", false, true)
    for _, mdir in ipairs(marketplaces) do
      local plugins_dir = mdir .. "/plugins"
      if vim.fn.isdirectory(plugins_dir) == 1 then
        local plugins = vim.fn.glob(plugins_dir .. "/*", false, true)
        for _, pdir in ipairs(plugins) do
          local sdir = pdir .. "/skills"
          for _, s in ipairs(scan_dir(sdir, "plugin")) do
            table.insert(skills, s)
          end
        end
      end
    end
  end

  return skills
end

--- Full filesystem scan (fallback when no manifest).
--- @return claude_code.Skill[]
local function filesystem_scan()
  local config = require("claude-code-completion").get_config()
  local home = vim.fn.expand("~")
  local claude_dir = home .. "/.claude"
  local cwd = vim.fn.getcwd()
  local skills = {}

  -- Start with builtins
  for _, s in ipairs(builtins.get()) do
    table.insert(skills, s)
  end

  -- User skills
  if config.scan_paths.user then
    for _, s in ipairs(scan_dir(claude_dir .. "/skills", "user")) do
      table.insert(skills, s)
    end
  end

  -- Project skills
  if config.scan_paths.project then
    for _, s in ipairs(scan_dir(cwd .. "/.claude/skills", "project")) do
      table.insert(skills, s)
    end
  end

  -- Plugin skills
  if config.scan_paths.plugins then
    for _, s in ipairs(scan_plugins(claude_dir)) do
      table.insert(skills, s)
    end
  end

  return skills
end

--- Get skills (cached). Tries manifest first, then filesystem scan.
--- @return claude_code.Skill[]
function M.get_skills()
  if cache then
    return cache
  end

  -- Try the SessionStart hook manifest
  local manifest_skills = read_manifest()
  if manifest_skills and #manifest_skills > 0 then
    cache = manifest_skills
    return cache
  end

  -- Fallback to filesystem scan
  cache = filesystem_scan()
  return cache
end

--- Clear cache and rescan on next call.
function M.refresh()
  cache = nil
end

return M
