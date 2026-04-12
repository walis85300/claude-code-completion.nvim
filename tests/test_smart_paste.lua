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

local function is_blockquoted(result)
  for _, line in ipairs(result) do
    if not line:match("^> ") then return false end
  end
  return #result > 0
end

local function is_link(result)
  return #result == 1 and result[1]:match("^%[.*%]%(.*%)$") ~= nil
end

print("\n=== smart-paste: code detection (vim.filetype.match) ===")

-- vim.filetype.match detects languages with strong signals (shebangs, modelines)
do
  local result = paste.format("#!/usr/bin/env bash\necho hello\nexit 0")
  check("shebang → fenced", is_fenced(result))
end

do
  local result = paste.format("#!/usr/bin/env python3\nprint('hello')")
  check("python shebang → fenced", is_fenced(result))
end

do
  local result = paste.format("#!/usr/bin/env node\nconsole.log('hi')")
  check("node shebang → fenced", is_fenced(result))
end

-- Short snippets without shebangs: vim.filetype.match may not detect these.
-- format() returns them as-is (passthrough or blockquote), which is correct.
do
  local result = paste.format("const x = 1")
  check("short snippet → not fenced (no shebang)", not is_fenced(result))
end

-- Code inside fences: detect_language returns the fence content preserved
do
  local result = paste.format("#!/bin/sh\nset -e\necho done")
  if is_fenced(result) then
    check("fenced content preserved", result[2] == "#!/bin/sh")
  else
    check("fenced content preserved", false, "not fenced")
  end
end

print("\n=== smart-paste: URL detection ===")

do
  check("https → link", is_link(paste.format("https://github.com/user/repo")))
  check("http → link", is_link(paste.format("http://localhost:3000")))
  check("URL with space → NOT link", not is_link(paste.format("https://example.com not url")))
  check("no scheme → NOT link", not is_link(paste.format("example.com/path")))
  check("multiline URL → NOT link", not is_link(paste.format("https://a.com\nhttps://b.com")))
end

print("\n=== smart-paste: blockquote ===")

do
  local long = "One.\nTwo.\nThree.\nFour.\nFive."
  local result = paste.format(long)
  check("5 lines → blockquoted", is_blockquoted(result))
  check("preserves first line", result[1] == "> One.")
  check("preserves last line", result[#result] == "> Five.")
end

do
  local three = "One.\nTwo.\nThree."
  local result = paste.format(three)
  check("3 lines → NOT blockquoted", not is_blockquoted(result))
end

print("\n=== smart-paste: passthrough ===")

do
  check("short text", paste.format("hello")[1] == "hello")
  check("2 lines", #paste.format("a\nb") == 2)
  check("empty", #paste.format("") == 1)
  check("whitespace-only", #paste.format("  \n  ") >= 1)
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
