--- Pure-Lua YAML frontmatter parser for Claude Code skill .md files.
local M = {}

--- Parse YAML frontmatter from a markdown string.
--- @param content string
--- @return table<string, string>
function M.parse(content)
  local result = {}
  if not content:match("^%-%-%-\r?\n") then
    return result
  end

  local after_open = content:find("\n", 4)
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
      value = value:gsub("^[\"']", ""):gsub("[\"']$", ""):gsub("%s+$", "")
      result[key] = value
    end
  end

  return result
end

--- Parse a skill .md file and return name + description, or nil if skipped.
--- Only reads the frontmatter header, not the full file body.
--- @param filepath string Absolute path to the .md file
--- @return { name: string, description: string }|nil
function M.parse_skill_file(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return nil
  end

  -- Read only the frontmatter header (stop at closing ---)
  local lines = {}
  local found_open = false
  for line in f:lines() do
    if not found_open then
      if line:match("^%-%-%-") then
        found_open = true
        lines[#lines + 1] = line
      else
        break -- no frontmatter
      end
    else
      lines[#lines + 1] = line
      if line:match("^%-%-%-") then
        break -- closing delimiter
      end
    end
  end
  f:close()

  if #lines < 2 then
    return nil
  end

  local content = table.concat(lines, "\n")
  local fm = M.parse(content)

  if fm["user-invocable"] == "false" then
    return nil
  end

  local name = fm.name
  if not name or name == "" then
    name = vim.fn.fnamemodify(filepath, ":t:r")
  end

  local desc = fm.description or ""
  -- Clean up: literal \n → space, strip XML/HTML tags, collapse whitespace, truncate
  desc = desc:gsub("\\n", " ")
  desc = desc:gsub("<[^>]+>", "")
  desc = desc:gsub("%s+", " ")
  desc = desc:gsub("^%s+", ""):gsub("%s+$", "")
  if #desc > 120 then
    desc = desc:sub(1, 117) .. "..."
  end

  return {
    name = name,
    description = desc,
  }
end

return M
