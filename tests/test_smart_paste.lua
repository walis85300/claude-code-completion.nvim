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

--- Check that format() wraps text in a code fence (any language).
local function is_fenced(result)
  return #result >= 3 and result[1]:match("^```") and result[#result] == "```"
end

--- Check that format() wraps text as a blockquote.
local function is_blockquoted(result)
  for _, line in ipairs(result) do
    if not line:match("^> ") then return false end
  end
  return #result > 0
end

--- Check that format() wraps text as a markdown link.
local function is_link(result)
  return #result == 1 and result[1]:match("^%[.*%]%(.*%)$") ~= nil
end

print("\n=== smart-paste: code detection ===")

local code_samples = {
  { "import React from 'react'\nconst App = () => {}\nexport default App", "typescript import" },
  { "def hello():\n    print('world')\n    return True", "python def" },
  { "package main\n\nfunc main() {\n    fmt.Println(\"hello\")\n}", "go package" },
  { "local M = {}\nfunction M.setup()\nend\nreturn M", "lua local" },
  { "#!/usr/bin/env bash\necho hello\nexit 0", "bash shebang" },
  { "SELECT * FROM users\nWHERE id = 1;", "sql select" },
  { "FROM node:20\nRUN npm install\nCOPY . .", "dockerfile" },
}

for _, sample in ipairs(code_samples) do
  local result = paste.format(sample[1])
  check(sample[2] .. " → fenced", is_fenced(result), "got first line: " .. (result[1] or "nil"))
end

do
  -- Verify the fence contains SOME language tag (not just ```)
  local result = paste.format("import React from 'react'\nexport default App")
  local lang = result[1]:match("^```(.+)")
  check("code fence has language tag", lang ~= nil and lang ~= "", "got: " .. (result[1] or "nil"))
end

do
  -- Code content is preserved inside the fence
  local result = paste.format("const x = 1\nconst y = 2")
  if is_fenced(result) then
    check("code content preserved", result[2] == "const x = 1")
  else
    check("code content preserved", false, "not fenced")
  end
end

print("\n=== smart-paste: URL detection ===")

do
  local result = paste.format("https://github.com/walis85300/claude-code-completion.nvim")
  check("https URL → link", is_link(result), "got: " .. result[1])
end

do
  local result = paste.format("http://localhost:3000/api/health")
  check("http URL → link", is_link(result))
end

do
  local result = paste.format("https://example.com not a url")
  check("URL with space → NOT a link", not is_link(result))
end

do
  local result = paste.format("not-a-url.com/path")
  check("no scheme → NOT a link", not is_link(result))
end

print("\n=== smart-paste: blockquote ===")

do
  local long = "Line one.\nLine two.\nLine three.\nLine four.\nLine five."
  local result = paste.format(long)
  check("long text → blockquoted", is_blockquoted(result))
  check("blockquote preserves content", result[1] == "> Line one.")
end

print("\n=== smart-paste: passthrough ===")

do
  local result = paste.format("short text")
  check("short text passes through", #result == 1 and result[1] == "short text")
end

do
  local result = paste.format("line one\nline two")
  check("2 lines pass through", #result == 2 and not is_fenced(result) and not is_blockquoted(result))
end

do
  local result = paste.format("")
  check("empty → passthrough", #result == 1)
end

print("\n=== smart-paste: edge cases ===")

do
  local result = paste.format("  \n  \n  ")
  check("whitespace-only passes through", #result >= 1)
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
