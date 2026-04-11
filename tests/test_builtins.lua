--- Tests for builtins module.
local builtins = require("claude-code-completion.builtins")

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

print("\n=== builtins ===")

local skills = builtins.get()

check("returns a table", type(skills) == "table")
check("has entries", #skills > 0, "got: " .. #skills)

-- Verify structure
local first = skills[1]
check("entry has name", type(first.name) == "string" and first.name ~= "")
check("entry has description", type(first.description) == "string" and first.description ~= "")
check("entry has source", first.source == "builtin" or first.source == "bundled")

-- Check prompt-meaningful skills exist
local names = {}
for _, s in ipairs(skills) do
  names[s.name] = true
end
check("/commit exists", names["commit"] == true)
check("/review exists", names["review"] == true)
check("/compact exists", names["compact"] == true)
check("/simplify exists (bundled)", names["simplify"] == true)
check("/remember exists (bundled)", names["remember"] == true)
check("/debug exists (bundled)", names["debug"] == true)
check("/commit-push-pr exists", names["commit-push-pr"] == true)

-- CLI-only commands must NOT be present (they don't belong in the editor)
check("no /exit (CLI-only)", names["exit"] == nil)
check("no /clear (CLI-only)", names["clear"] == nil)
check("no /login (CLI-only)", names["login"] == nil)
check("no /logout (CLI-only)", names["logout"] == nil)
check("no /theme (CLI-only)", names["theme"] == nil)
check("no /vim (CLI-only)", names["vim"] == nil)
check("no /color (CLI-only)", names["color"] == nil)
check("no /help (CLI-only)", names["help"] == nil)
check("no /mcp (CLI-only)", names["mcp"] == nil)
check("no /plugin (CLI-only)", names["plugin"] == nil)
check("no /cost (CLI-only)", names["cost"] == nil)
check("no /status (CLI-only)", names["status"] == nil)

-- Internal commands still absent
check("no backfill-sessions", names["backfill-sessions"] == nil)
check("no break-cache", names["break-cache"] == nil)
check("no bughunter", names["bughunter"] == nil)

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
