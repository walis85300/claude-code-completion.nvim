--- Tests for init module: buffer detection and slash-col finding.
local init = require("claude-code-completion")

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

print("\n=== is_claude_buffer ===")

do
  -- Create a buffer with a claude prompt name
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "/tmp/claude-prompt-abc123.md")
  check("detects claude-prompt buffer", init.is_claude_buffer(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "/var/folders/xx/T/claude-prompt-def456.md")
  check("detects in non-/tmp tmpdir", init.is_claude_buffer(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "/home/user/project/README.md")
  check("rejects non-claude buffer", not init.is_claude_buffer(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "/tmp/not-claude-prompt.md")
  check("rejects similar but wrong name", not init.is_claude_buffer(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

print("\n=== find_slash_col ===")

do
  local col = init.find_slash_col("/commit", 4)
  check("slash at line start", col == 1, "got: " .. tostring(col))
end

do
  local col = init.find_slash_col("text /review", 12)
  check("slash after whitespace", col == 6, "got: " .. tostring(col))
end

do
  local col = init.find_slash_col("hello/world", 8)
  check("slash mid-word returns nil", col == nil)
end

do
  local col = init.find_slash_col("  /comp", 7)
  check("slash after leading spaces", col == 3, "got: " .. tostring(col))
end

do
  local col = init.find_slash_col("no slash here", 10)
  check("no slash returns nil", col == nil)
end

do
  local col = init.find_slash_col("/", 1)
  check("just a slash", col == 1, "got: " .. tostring(col))
end

do
  local col = init.find_slash_col("", 0)
  check("empty line returns nil", col == nil)
end

print("\n=== setup ===")

do
  init._reset()
  init.setup({})
  check("setup runs without error", true)

  local cfg = init.get_config()
  check("default config applied", cfg.scan_paths.user == true)
  check("default config plugins", cfg.scan_paths.plugins == true)
end

do
  init._reset()
  init.setup({ scan_paths = { user = false, project = true, plugins = true } })
  local cfg = init.get_config()
  check("custom config user=false", cfg.scan_paths.user == false)
  check("custom config project=true", cfg.scan_paths.project == true)
end

do
  -- Double setup should be a no-op
  init._reset()
  init.setup({})
  init.setup({ scan_paths = { user = false, project = false, plugins = false } })
  local cfg = init.get_config()
  check("second setup is no-op", cfg.scan_paths.user == true)
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
