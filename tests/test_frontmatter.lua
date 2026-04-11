--- Tests for the frontmatter parser.
local fm = require("claude-code-completion.frontmatter")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"
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

print("\n=== frontmatter.parse ===")

do
  local r = fm.parse("---\nname: foo\ndescription: bar\n---\nbody")
  check("parses name", r.name == "foo", "got: " .. tostring(r.name))
  check("parses description", r.description == "bar", "got: " .. tostring(r.description))
end

do
  local r = fm.parse("---\nname: \"quoted\"\n---\n")
  check("strips double quotes", r.name == "quoted", "got: " .. tostring(r.name))
end

do
  local r = fm.parse("---\nname: 'single'\n---\n")
  check("strips single quotes", r.name == "single", "got: " .. tostring(r.name))
end

do
  local r = fm.parse("no frontmatter here")
  check("no frontmatter returns empty", next(r) == nil)
end

do
  local r = fm.parse("---\n---\nbody")
  check("empty frontmatter returns empty", next(r) == nil)
end

do
  local r = fm.parse("---\nuser-invocable: false\n---\n")
  check("parses hyphenated keys", r["user-invocable"] == "false")
end

print("\n=== frontmatter.parse_skill_file ===")

do
  local s = fm.parse_skill_file(fixtures .. "/skill_with_frontmatter.md")
  check("returns skill", s ~= nil)
  check("name from frontmatter", s and s.name == "test-skill", "got: " .. tostring(s and s.name))
  check("description from frontmatter", s and s.description == "A test skill for unit tests")
end

do
  local s = fm.parse_skill_file(fixtures .. "/skill_no_name.md")
  check("fallback name from filename", s and s.name == "skill_no_name", "got: " .. tostring(s and s.name))
  check("description present", s and s.description == "Skill without a name field")
end

do
  local s = fm.parse_skill_file(fixtures .. "/skill_hidden.md")
  check("user-invocable false returns nil", s == nil)
end

do
  local s = fm.parse_skill_file(fixtures .. "/skill_no_frontmatter.md")
  check("no frontmatter returns nil", s == nil)
end

do
  local s = fm.parse_skill_file(fixtures .. "/skill_empty_frontmatter.md")
  check("empty frontmatter uses filename", s and s.name == "skill_empty_frontmatter", "got: " .. tostring(s and s.name))
end

do
  local s = fm.parse_skill_file(fixtures .. "/skill_quoted_values.md")
  check("quoted name stripped", s and s.name == "quoted-skill", "got: " .. tostring(s and s.name))
  check("quoted description stripped", s and s.description == "A skill with quoted frontmatter values")
end

do
  local s = fm.parse_skill_file(fixtures .. "/nonexistent.md")
  check("nonexistent file returns nil", s == nil)
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
