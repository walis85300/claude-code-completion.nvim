--- Tests for agent discovery.
local agents = require("claude-code-completion.agents")

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

print("\n=== agents: built-in ===")

do
  local all = agents.get_agents()
  check("returns a table", type(all) == "table")
  check("has built-in agents", #all >= 4, "got: " .. #all)

  local names = {}
  for _, a in ipairs(all) do
    names[a.name] = a
  end

  check("general-purpose exists", names["general-purpose"] ~= nil)
  check("Explore exists", names["Explore"] ~= nil)
  check("Plan exists", names["Plan"] ~= nil)
  check("claude-code-guide exists", names["claude-code-guide"] ~= nil)

  local gp = names["general-purpose"]
  check("has description", gp and gp.description ~= "")
  check("has source", gp and gp.source == "builtin")
end

print("\n=== agents: structure ===")

do
  local all = agents.get_agents()
  for _, a in ipairs(all) do
    check(a.name .. " has name", type(a.name) == "string" and a.name ~= "")
    check(a.name .. " has description", type(a.description) == "string")
    check(a.name .. " has source", a.source == "builtin" or a.source == "user" or a.source == "project" or a.source == "plugin")
    break -- just check first entry structure
  end
end

print("\n=== agents: deduplication ===")

do
  -- Refresh and re-get should not produce duplicates
  agents.refresh()
  local all = agents.get_agents()
  local seen = {}
  local has_dupes = false
  for _, a in ipairs(all) do
    if seen[a.name] then
      has_dupes = true
      break
    end
    seen[a.name] = true
  end
  check("no duplicate agent names", not has_dupes)
end

print("\n=== agents: refresh ===")

do
  agents.refresh()
  local a1 = agents.get_agents()
  local a2 = agents.get_agents()
  check("cached after first call", a1 == a2)

  agents.refresh()
  local a3 = agents.get_agents()
  check("new table after refresh", a1 ~= a3)
  check("same count after refresh", #a1 == #a3)
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
