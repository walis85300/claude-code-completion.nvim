--- Tests for @ file completion.
local files = require("claude-code-completion.files")

local pass, fail = 0, 0

--- @param name string
--- @param ok boolean
--- @param msg string|nil
local function check(name, ok, msg)
  if ok then
    pass = pass + 1
    print("  PASS: " .. name)
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (msg and (" — " .. msg) or ""))
  end
end

print("\n=== find_at_col ===")

do
  local col, prefix = files.find_at_col("@src/file.ts", 12)
  check("@ at line start", col == 1, "col: " .. tostring(col))
  check("prefix extracted", prefix == "src/file.ts", "prefix: " .. tostring(prefix))
end

do
  local col, prefix = files.find_at_col("text @src", 9)
  check("@ after whitespace", col == 6, "col: " .. tostring(col))
  check("prefix after whitespace", prefix == "src", "prefix: " .. tostring(prefix))
end

do
  local col = files.find_at_col("email@example.com", 17)
  check("@ mid-word returns nil", col == nil)
end

do
  local col, prefix = files.find_at_col("@", 1)
  check("just @ sign", col == 1, "col: " .. tostring(col))
  check("empty prefix", prefix == "", "prefix: " .. tostring(prefix))
end

do
  local col = files.find_at_col("no at here", 10)
  check("no @ returns nil", col == nil)
end

do
  local col = files.find_at_col("", 0)
  check("empty line returns nil", col == nil)
end

do
  local col, prefix = files.find_at_col("  @lua/", 7)
  check("@ after spaces", col == 3, "col: " .. tostring(col))
  check("prefix with trailing slash", prefix == "lua/", "prefix: " .. tostring(prefix))
end

print("\n=== get_files ===")

-- Test from the plugin's own directory (we know the structure)
do
  local entries = files.get_files("")
  check("returns entries from cwd", #entries > 0, "got: " .. #entries)

  local has_lua = false
  for _, e in ipairs(entries) do
    if e.path == "lua/" and e.is_dir then
      has_lua = true
    end
  end
  check("finds lua/ directory", has_lua)
end

do
  local entries = files.get_files("lua/")
  local has_module = false
  for _, e in ipairs(entries) do
    if e.path:match("^lua/claude%-code%-completion/") then
      has_module = true
    end
  end
  check("finds files in subdirectory", has_module)
end

do
  local entries = files.get_files("nonexistent-dir/")
  check("nonexistent dir returns empty", #entries == 0)
end

do
  -- .git should be ignored
  local entries = files.get_files("")
  local has_git = false
  for _, e in ipairs(entries) do
    if e.path:match("^%.git/") or e.path == ".git/" then
      has_git = true
    end
  end
  check(".git is ignored", not has_git)
end

do
  local entries = files.get_files("")
  for _, e in ipairs(entries) do
    if e.is_dir then
      check("directories end with /", e.path:sub(-1) == "/", "got: " .. e.path)
      break
    end
  end
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
