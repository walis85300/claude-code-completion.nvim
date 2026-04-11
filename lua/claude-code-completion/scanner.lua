--- Skill discovery: reads SessionStart hook manifest or falls back to filesystem scan.
local M = {}

local discovery = require("claude-code-completion.discovery")

--- @type claude_code.Skill[]|nil
local cache = nil

--- Get the manifest path for the current project CWD.
--- @return string
function M.get_manifest_path()
  local cwd = discovery.get_cwd()
  local hash = vim.fn.sha256(cwd):sub(1, 12)
  return discovery.get_tmpdir() .. "/claude-skills-" .. hash .. ".json"
end

--- Try to read the manifest written by the SessionStart hook.
--- @return claude_code.Skill[]|nil
local function read_manifest()
  local paths = {
    M.get_manifest_path(),
    discovery.get_tmpdir() .. "/claude-skills-latest.json",
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

--- Full filesystem scan (fallback when no manifest).
--- @return claude_code.Skill[]
local function filesystem_scan()
  local cfg = require("claude-code-completion").get_config()
  local skills = {}

  vim.list_extend(skills, require("claude-code-completion.builtins").get())
  vim.list_extend(skills, discovery.scan_all("skills", cfg.scan_paths))

  return discovery.dedupe(skills)
end

--- Get skills (cached). Tries manifest first, then filesystem scan.
--- @return claude_code.Skill[]
function M.get_skills()
  if cache then
    return cache
  end

  local manifest_skills = read_manifest()
  if manifest_skills and #manifest_skills > 0 then
    cache = discovery.dedupe(manifest_skills)
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
