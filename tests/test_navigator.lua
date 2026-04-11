--- Tests for section navigator.
local nav = require("claude-code-completion.navigator")

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

print("\n=== navigator: get_headings ===")

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Problem",
    "",
    "Some description here.",
    "",
    "## Requirements",
    "",
    "- R1. First requirement",
    "- R2. Second requirement",
    "",
    "## Context",
    "",
    "### Relevant Code",
    "",
    "Some code references.",
    "",
    "# Implementation",
    "",
    "## Unit 1",
  })

  local headings = nav.get_headings(buf)

  check("finds all headings", #headings == 6, "got: " .. #headings)

  check("h1 Problem at line 1", headings[1].line == 1 and headings[1].text == "Problem" and headings[1].level == 1)
  check("h2 Requirements at line 5", headings[2].line == 5 and headings[2].text == "Requirements" and headings[2].level == 2)
  check("h2 Context at line 10", headings[3].line == 10 and headings[3].text == "Context")
  check("h3 Relevant Code at line 12", headings[4].line == 12 and headings[4].level == 3)
  check("h1 Implementation at line 16", headings[5].line == 16 and headings[5].level == 1)
  check("h2 Unit 1 at line 18", headings[6].line == 18 and headings[6].text == "Unit 1")

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "No headings here.",
    "Just plain text.",
  })

  local headings = nav.get_headings(buf)
  check("no headings returns empty", #headings == 0)

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })

  local headings = nav.get_headings(buf)
  check("empty buffer returns empty", #headings == 0)

  vim.api.nvim_buf_delete(buf, { force = true })
end

print("\n=== navigator: next/prev ===")

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Section 1",
    "text",
    "# Section 2",
    "text",
    "# Section 3",
  })

  -- Start at line 1
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  nav.next(buf)
  local pos = vim.api.nvim_win_get_cursor(0)
  check("next jumps to Section 2", pos[1] == 3, "got line: " .. pos[1])

  nav.next(buf)
  pos = vim.api.nvim_win_get_cursor(0)
  check("next jumps to Section 3", pos[1] == 5, "got line: " .. pos[1])

  nav.prev(buf)
  pos = vim.api.nvim_win_get_cursor(0)
  check("prev jumps back to Section 2", pos[1] == 3, "got line: " .. pos[1])

  nav.prev(buf)
  pos = vim.api.nvim_win_get_cursor(0)
  check("prev jumps back to Section 1", pos[1] == 1, "got line: " .. pos[1])

  vim.api.nvim_buf_delete(buf, { force = true })
end

print("\n=== navigator: edge cases ===")

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Only heading",
    "some text below",
  })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  -- next with no more headings — should stay put (notifies user)
  local before = vim.api.nvim_win_get_cursor(0)[1]
  nav.next(buf)
  local after = vim.api.nvim_win_get_cursor(0)[1]
  check("next at last heading stays", after == before, "moved to: " .. after)

  vim.api.nvim_buf_delete(buf, { force = true })
end

do
  -- Headings with special chars
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "## What's the `plan`?",
    "text",
    "### Code (example)",
  })

  local headings = nav.get_headings(buf)
  check("heading with backticks", headings[1].text == "What's the `plan`?")
  check("heading with parens", headings[2].text == "Code (example)")

  vim.api.nvim_buf_delete(buf, { force = true })
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
