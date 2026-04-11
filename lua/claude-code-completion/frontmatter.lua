--- Pure-Lua YAML frontmatter parser for Claude Code skill .md files.
local M = {}

--- Parse YAML frontmatter from a markdown string.
--- @param content string
--- @return table<string, string>
function M.parse(content)
  local result = {}
  local start_pat = "^%-%-%-\r?\n"
  local s = content:match(start_pat)
  if not s then
    return result
  end

  -- Find the closing ---
  local after_open = content:find("\n", 4) -- skip first ---
  if not after_open then
    return result
  end

  local close = content:find("\n%-%-%-", after_open)
  if not close then
    return result
  end

  local fm_block = content:sub(after_open + 1, close - 1)

  for line in fm_block:gmatch("[^\r\n]+") do
    local key, value = line:match("^(%S+)%s*:%s*(.+)")
    if key and value then
      -- Strip surrounding quotes
      value = value:gsub("^[\"']", ""):gsub("[\"']$", ""):gsub("%s+$", "")
      result[key] = value
    end
  end

  return result
end

--- Parse a skill .md file and return skill info, or nil if skipped.
--- @param filepath string Absolute path to the .md file
--- @return claude_code.Skill|nil
function M.parse_skill_file(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return nil
  end

  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return nil
  end

  local fm = M.parse(content)

  -- Skip non-user-invocable skills
  if fm["user-invocable"] == "false" then
    return nil
  end

  -- Name: from frontmatter or filename stem
  local name = fm.name
  if not name or name == "" then
    name = vim.fn.fnamemodify(filepath, ":t:r")
  end

  local description = fm.description or ""

  return {
    name = name,
    description = description,
    source = "user", -- caller overrides this
  }
end

return M
