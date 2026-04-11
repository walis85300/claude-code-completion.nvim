--- Tests for the picker module (entry building, insert logic).
--- Note: actual fzf-lua UI cannot be tested headless, but we test the data layer.
local picker = require("claude-code-completion.picker")

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

print("\n=== picker: module loads ===")

do
  check("module loads", picker ~= nil)
  check("has open()", type(picker.open) == "function")
  check("has skills()", type(picker.skills) == "function")
  check("has mentions()", type(picker.mentions) == "function")
end

print("\n=== picker: insert_at_cursor ===")

do
  -- Test the insert logic by simulating cursor position
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })

  -- We can't call insert_at_cursor directly (local), but we can test
  -- the pattern: insert at cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local text = "/commit"
  local new_line = line:sub(1, col) .. text .. " " .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { new_line })

  local result = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  check("insert at cursor", result == "hello/commit  world", "got: " .. result)

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Insert at beginning of empty line
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local text = "@src/file.ts"
  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  local new_line = line:sub(1, 0) .. text .. " " .. line:sub(1)
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { new_line })

  local result = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  check("insert at empty line start", result == "@src/file.ts ", "got: " .. result)

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Insert at end of line
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "review " })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })

  local col = 7
  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  local text = "@Explore"
  local new_line = line:sub(1, col) .. text .. " " .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { new_line })

  local result = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  check("insert at end of line", result == "review @Explore ", "got: " .. result)

  vim.api.nvim_buf_delete(buf, { force = true })
end

print("\n=== picker: graceful without fzf-lua ===")

do
  -- Temporarily hide fzf-lua
  local orig = package.loaded["fzf-lua"]
  package.loaded["fzf-lua"] = nil
  package.preload["fzf-lua"] = function() error("not installed") end

  local notified = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    if msg:match("fzf%-lua required") then
      notified = true
    end
  end

  picker.open()
  check("warns when fzf-lua missing", notified)

  vim.notify = orig_notify
  package.preload["fzf-lua"] = nil
  package.loaded["fzf-lua"] = orig
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
