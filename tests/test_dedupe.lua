--- Tests for skill deduplication (reproduces duplicate plugin versions issue).
local scanner = require("claude-code-completion.scanner")

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

print("\n=== dedupe: plugin version duplicates (issue #2) ===")

-- Reproduce the exact bug: multiple plugin versions in cache produce
-- the same skill name multiple times (e.g. ce:work from v1.0, v1.1, v1.2)
do
  local skills = {
    { name = "commit", description = "Create a git commit", source = "builtin" },
    { name = "ce:work", description = "Execute work v1.0", source = "plugin" },
    { name = "ce:work", description = "Execute work v1.1", source = "plugin" },
    { name = "ce:work", description = "Execute work v1.2", source = "plugin" },
    { name = "ce:work", description = "Execute work v1.3", source = "plugin" },
    { name = "ce:work", description = "Execute work v1.4", source = "plugin" },
    { name = "workflow", description = "Run workflow v1.0", source = "plugin" },
    { name = "workflow", description = "Run workflow v1.1", source = "plugin" },
    { name = "workflow", description = "Run workflow v1.2", source = "plugin" },
    { name = "workflow", description = "Run workflow v1.3", source = "plugin" },
    { name = "review", description = "Code review", source = "builtin" },
  }

  local result = scanner._dedupe(skills)

  check("removes duplicates", #result == 4, "got: " .. #result .. " expected: 4")

  local names = {}
  for _, s in ipairs(result) do
    names[#names + 1] = s.name
  end
  local joined = table.concat(names, ",")
  check("keeps correct unique names", joined == "commit,ce:work,workflow,review", "got: " .. joined)
end

-- First occurrence wins — builtins should take priority over plugins
do
  local skills = {
    { name = "review", description = "Built-in review", source = "builtin" },
    { name = "review", description = "Plugin review", source = "plugin" },
  }

  local result = scanner._dedupe(skills)

  check("first occurrence wins", #result == 1)
  check("builtin beats plugin", result[1].source == "builtin", "got: " .. result[1].source)
  check("keeps builtin description", result[1].description == "Built-in review")
end

-- No duplicates — should pass through unchanged
do
  local skills = {
    { name = "commit", description = "Commit", source = "builtin" },
    { name = "review", description = "Review", source = "builtin" },
    { name = "my-skill", description = "Custom", source = "user" },
  }

  local result = scanner._dedupe(skills)
  check("no-op when no duplicates", #result == 3)
end

-- Empty input
do
  local result = scanner._dedupe({})
  check("empty input returns empty", #result == 0)
end

-- Single item
do
  local result = scanner._dedupe({ { name = "solo", description = "Only one", source = "user" } })
  check("single item passes through", #result == 1)
  check("single item preserved", result[1].name == "solo")
end

-- All duplicates of the same name
do
  local skills = {}
  for i = 1, 10 do
    skills[#skills + 1] = { name = "ce:work", description = "version " .. i, source = "plugin" }
  end

  local result = scanner._dedupe(skills)
  check("10 identical names -> 1 result", #result == 1, "got: " .. #result)
  check("keeps first version", result[1].description == "version 1")
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
