--- File completion for @mentions in Claude Code prompt buffers.
--- Walks the project directory (CWD inherited from Claude Code) and
--- returns files/directories as completion candidates.
local M = {}

local IGNORE_DIRS = {
  [".git"] = true,
  ["node_modules"] = true,
  ["dist"] = true,
  ["build"] = true,
  ["__pycache__"] = true,
  [".next"] = true,
  [".nuxt"] = true,
  ["vendor"] = true,
  ["target"] = true,
  [".cache"] = true,
  ["_build"] = true,
  [".elixir_ls"] = true,
}

local MAX_DEPTH = 3
local MAX_RESULTS = 50

--- Walk a directory recursively using vim.uv, yielding relative paths.
--- @param base string Absolute path to project root
--- @param rel string Relative path prefix (empty string for root)
--- @param depth number Current depth
--- @param results table Accumulator
local function walk(base, rel, depth, results)
  if depth > MAX_DEPTH or #results >= MAX_RESULTS then
    return
  end

  local dir = rel == "" and base or (base .. "/" .. rel)
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return
  end

  while #results < MAX_RESULTS do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    -- Skip hidden files and ignored directories
    if name:sub(1, 1) == "." and IGNORE_DIRS[name] == nil then
      goto continue
    end
    if IGNORE_DIRS[name] then
      goto continue
    end

    local rel_path = rel == "" and name or (rel .. "/" .. name)

    if type == "directory" then
      results[#results + 1] = { path = rel_path .. "/", is_dir = true }
      walk(base, rel_path, depth + 1, results)
    elseif type == "file" then
      results[#results + 1] = { path = rel_path, is_dir = false }
    end

    ::continue::
  end
end

--- Find the @ mention start column and extract the prefix.
--- Valid positions: line start or after whitespace.
--- @param line string
--- @param col number 1-indexed cursor column
--- @return number|nil at_col 1-indexed column of the `@`
--- @return string prefix The partial path typed so far
function M.find_at_col(line, col)
  for i = col, 1, -1 do
    local ch = line:sub(i, i)
    if ch == "@" then
      if i == 1 or line:sub(i - 1, i - 1):match("%s") then
        local prefix = line:sub(i + 1, col)
        return i, prefix
      end
      return nil, ""
    elseif ch:match("%s") then
      return nil, ""
    end
  end
  return nil, ""
end

--- Get file completions for a given prefix.
--- @param prefix string Partial path (e.g. "src/comp" or "")
--- @return table[] Array of { path: string, is_dir: boolean }
function M.get_files(prefix)
  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  local results = {}

  if prefix:find("/") then
    -- Prefix has a directory component — search within that subdir
    local dir_part = prefix:match("^(.+)/")
    local search_base = cwd .. "/" .. dir_part
    local stat = vim.uv.fs_stat(search_base)
    if stat and stat.type == "directory" then
      walk(cwd, dir_part, 1, results)
    end
  else
    -- No directory separator — search from project root
    walk(cwd, "", 0, results)
  end

  return results
end

return M
