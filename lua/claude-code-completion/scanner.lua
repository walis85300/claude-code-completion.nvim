--- Skill discovery: reads SessionStart hook manifest or falls back to filesystem scan.
local M = {}

--- @type claude_code.Skill[]|nil
local cache = nil

--- @return string
local function get_tmpdir()
  local tmpdir = vim.uv.os_getenv("TMPDIR")
  return (tmpdir and tmpdir ~= "") and tmpdir or "/tmp"
end

--- @return string
local function get_claude_dir()
  return (vim.uv.os_homedir() or vim.fn.expand("~")) .. "/.claude"
end

--- Get the manifest path for the current project CWD.
--- @return string
function M.get_manifest_path()
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  local hash = vim.fn.sha256(cwd):sub(1, 12)
  return get_tmpdir() .. "/claude-skills-" .. hash .. ".json"
end

--- Try to read the manifest written by the SessionStart hook.
--- @return claude_code.Skill[]|nil
local function read_manifest()
  local paths = {
    M.get_manifest_path(),
    get_tmpdir() .. "/claude-skills-latest.json",
  }

  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local ok, data = pcall(vim.json.decode, content)
      if ok and data and data.skills then
        --- @type claude_code.Skill[]
        local skills = {}
        for _, s in ipairs(data.skills) do
          skills[#skills + 1] = {
            name = s.name,
            description = s.description or "",
            source = s.source or "plugin",
          }
        end
        return skills
      end
    end
  end

  return nil
end

--- Scan a directory for skill .md files.
--- Handles flat (dir/*.md) and nested (dir/<name>/SKILL.md) layouts.
--- @param dir string
--- @param source string
--- @return claude_code.Skill[]
local function scan_dir(dir, source)
  local frontmatter = require("claude-code-completion.frontmatter")
  local skills = {}

  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then
    return skills
  end

  -- Flat: dir/*.md
  for _, filepath in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(filepath)
    if parsed then
      skills[#skills + 1] = { name = parsed.name, description = parsed.description, source = source }
    end
  end

  -- Nested: dir/<name>/SKILL.md
  for _, skill_file in ipairs(vim.fn.glob(dir .. "/*/SKILL.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(skill_file)
    if parsed then
      local name = (parsed.name == "SKILL" or parsed.name == "") and vim.fn.fnamemodify(skill_file, ":h:t") or parsed.name
      skills[#skills + 1] = { name = name, description = parsed.description, source = source }
    end
  end

  return skills
end

--- Scan all plugin skill directories under ~/.claude/plugins/.
--- @param claude_dir string
--- @return claude_code.Skill[]
local function scan_plugins(claude_dir)
  local skills = {}

  -- Plugin cache: plugins/cache/{marketplace}/{plugin}/{version}/skills/
  local skill_dirs = vim.fn.glob(claude_dir .. "/plugins/cache/*/*/*/skills", false, true)
  vim.list_extend(skill_dirs, vim.fn.glob(claude_dir .. "/plugins/marketplaces/*/plugins/*/skills", false, true))

  for _, sdir in ipairs(skill_dirs) do
    vim.list_extend(skills, scan_dir(sdir, "plugin"))
  end

  return skills
end

--- Full filesystem scan (fallback when no manifest).
--- @return claude_code.Skill[]
local function filesystem_scan()
  local cfg = require("claude-code-completion").get_config()
  local claude_dir = get_claude_dir()
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  local skills = {}

  vim.list_extend(skills, require("claude-code-completion.builtins").get())

  if cfg.scan_paths.user then
    vim.list_extend(skills, scan_dir(claude_dir .. "/skills", "user"))
  end
  if cfg.scan_paths.project then
    vim.list_extend(skills, scan_dir(cwd .. "/.claude/skills", "project"))
  end
  if cfg.scan_paths.plugins then
    vim.list_extend(skills, scan_plugins(claude_dir))
  end

  return skills
end

--- Get skills (cached). Tries manifest first, then filesystem scan.
--- @return claude_code.Skill[]
function M.get_skills()
  if cache then
    return cache
  end

  local manifest_skills = read_manifest()
  if manifest_skills and #manifest_skills > 0 then
    cache = manifest_skills
    return cache
  end

  cache = filesystem_scan()
  return cache
end

--- Clear cache and rescan on next call.
function M.refresh()
  cache = nil
end

return M
