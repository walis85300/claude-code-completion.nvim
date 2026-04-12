--- Tests for smart paste formatting.
local paste = require("claude-code-completion.smart-paste")

local pass, fail = 0, 0

local function check(name, ok, msg)
  if ok then
    pass = pass + 1
    print("  PASS: " .. name)
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (msg and (" — " .. msg) or ""))
  end
end

local function is_fenced(result)
  return #result >= 3 and result[1]:match("^```") and result[#result] == "```"
end

local function is_link(result)
  return #result == 1 and result[1]:match("^%[.*%]%(.*%)$") ~= nil
end

print("\n=== smart-paste: URLs ===")

check("https → link", is_link(paste.format("https://github.com/user/repo")))
check("http → link", is_link(paste.format("http://localhost:3000")))
check("URL with space → NOT link", not is_link(paste.format("https://example.com not url")))
check("no scheme → NOT link", not is_link(paste.format("example.com/path")))

print("\n=== smart-paste: multiline → code block ===")

do
  local result = paste.format("const x = 1\nconst y = 2")
  check("2 lines → fenced", is_fenced(result))
  check("content preserved", result[2] == "const x = 1")
end

do
  local result = paste.format("#!/usr/bin/env bash\necho hello")
  check("shebang → fenced with lang", is_fenced(result) and result[1] ~= "```")
end

do
  local result = paste.format("some random text\nmore text\nand more")
  check("unknown lang → fenced (no lang tag)", is_fenced(result) and result[1] == "```")
end

do
  local result = paste.format("line 1\nline 2\nline 3\nline 4\nline 5")
  check("5 lines → fenced", is_fenced(result))
  check("all lines inside fence", #result == 7) -- ``` + 5 lines + ```
end

print("\n=== smart-paste: single line → passthrough ===")

check("short text", paste.format("hello")[1] == "hello")
check("empty", #paste.format("") == 1)
check("single code line", paste.format("const x = 1")[1] == "const x = 1")

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
