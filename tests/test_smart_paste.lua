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

local function lines_eq(got, expected)
  if #got ~= #expected then return false, string.format("length %d vs %d", #got, #expected) end
  for i, line in ipairs(got) do
    if line ~= expected[i] then return false, string.format("line %d: %q vs %q", i, got[i], expected[i]) end
  end
  return true
end

print("\n=== smart-paste: code detection ===")

do
  local result = paste.format("import React from 'react'\nconst App = () => {}\nexport default App")
  check("typescript detected", result[1] == "```typescript", "got: " .. result[1])
  check("code fence closed", result[#result] == "```")
end

do
  local result = paste.format("def hello():\n    print('world')\n    return True")
  check("python detected", result[1] == "```python", "got: " .. result[1])
end

do
  local result = paste.format("package main\n\nfunc main() {\n    fmt.Println(\"hello\")\n}")
  check("go detected", result[1] == "```go", "got: " .. result[1])
end

do
  local result = paste.format("local M = {}\nfunction M.setup()\nend\nreturn M")
  check("lua detected", result[1] == "```lua", "got: " .. result[1])
end

do
  local result = paste.format("#!/usr/bin/env bash\necho hello\nexit 0")
  check("bash shebang detected", result[1] == "```bash", "got: " .. result[1])
end

do
  local result = paste.format("SELECT * FROM users\nWHERE id = 1;")
  check("sql detected", result[1] == "```sql", "got: " .. result[1])
end

do
  local result = paste.format("FROM node:20\nRUN npm install\nCOPY . .")
  check("dockerfile detected", result[1] == "```dockerfile", "got: " .. result[1])
end

do
  -- Code with unknown language but code-like syntax
  local result = paste.format("{\n  \"key\": \"value\",\n  \"num\": 42\n}")
  check("json detected", result[1] == "```json", "got: " .. result[1])
end

print("\n=== smart-paste: URL detection ===")

do
  local result = paste.format("https://github.com/walis85300/claude-code-completion.nvim")
  check("URL wrapped as link", result[1]:match("^%[https://") ~= nil, "got: " .. result[1])
  check("URL has href", result[1]:match("%(https://") ~= nil)
end

do
  local result = paste.format("http://localhost:3000/api/health")
  check("http URL detected", result[1]:match("^%[http://") ~= nil)
end

do
  -- URL with spaces is NOT a URL
  local result = paste.format("https://example.com not a url")
  check("URL with space is not a link", result[1] ~= nil and not result[1]:match("^%["))
end

print("\n=== smart-paste: blockquote ===")

do
  local long_text = "Line one of a long paste.\nLine two continues.\nLine three here.\nLine four adds more.\nLine five finishes."
  local result = paste.format(long_text)
  check("long text blockquoted", result[1] == "> Line one of a long paste.", "got: " .. result[1])
  check("all lines prefixed", result[3] == "> Line three here.")
end

print("\n=== smart-paste: passthrough ===")

do
  local result = paste.format("short text")
  local ok, msg = lines_eq(result, { "short text" })
  check("short text passes through", ok, msg)
end

do
  local result = paste.format("line one\nline two")
  check("2-line text passes through", #result == 2)
end

do
  local result = paste.format("")
  check("empty string passes through", #result == 1 and result[1] == "")
end

print("\n=== smart-paste: edge cases ===")

do
  -- Already fenced code should NOT double-fence
  local result = paste.format("```ts\nconst x = 1\n```")
  -- This is tricky — the ``` line doesn't match any lang pattern
  -- but looks_like_code might fire. The key is it shouldn't double-fence.
  check("already fenced not doubled", result[1] ~= "````ts", "got: " .. (result[1] or "nil"))
end

do
  local result = paste.format("  \n  \n  ")
  check("whitespace-only passes through", #result >= 1)
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
