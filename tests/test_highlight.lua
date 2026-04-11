--- Tests for semantic highlighting.
local highlight = require("claude-code-completion.highlight")

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

print("\n=== highlight: define_groups ===")

do
  highlight.define_groups()

  local groups = {
    "ClaudeSlashCommand",
    "ClaudeSlashUnknown",
    "ClaudeAtAgent",
    "ClaudeAtFile",
    "ClaudeAtUnknown",
  }
  for _, name in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = name })
    check(name .. " defined", hl and (hl.link ~= nil or next(hl) ~= nil), "not found")
  end
end

print("\n=== highlight: apply to buffer ===")

do
  -- Create a test buffer with known and unknown skills/mentions
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "/commit is a known skill",
    "/nonexistent-skill-xyz should be unknown",
    "@Explore is a known agent",
    "@random-unknown should be unknown",
    "no highlights on this line",
    "text /review at mid-line",
    "email@test.com should NOT highlight",
  })

  -- Need scanner and agents loaded for known sets
  require("claude-code-completion.scanner").get_skills()
  require("claude-code-completion.agents").get_agents()

  highlight.apply(buf)

  local ns = vim.api.nvim_create_namespace("claude_code_hl")
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })

  -- Collect highlights by line
  local hl_by_line = {}
  for _, mark in ipairs(marks) do
    local row = mark[2]
    hl_by_line[row] = hl_by_line[row] or {}
    hl_by_line[row][#hl_by_line[row] + 1] = mark[4].hl_group
  end

  -- Line 0: /commit → ClaudeSlashCommand (known)
  check("/commit highlighted as known", hl_by_line[0] and vim.tbl_contains(hl_by_line[0], "ClaudeSlashCommand"))

  -- Line 1: /nonexistent-skill-xyz → ClaudeSlashUnknown
  check("/nonexistent highlighted as unknown", hl_by_line[1] and vim.tbl_contains(hl_by_line[1], "ClaudeSlashUnknown"))

  -- Line 2: @Explore → ClaudeAtAgent (known)
  check("@Explore highlighted as agent", hl_by_line[2] and vim.tbl_contains(hl_by_line[2], "ClaudeAtAgent"))

  -- Line 3: @random-unknown → ClaudeAtUnknown
  check("@random-unknown highlighted as unknown", hl_by_line[3] and vim.tbl_contains(hl_by_line[3], "ClaudeAtUnknown"))

  -- Line 4: no highlights
  check("plain line has no highlights", hl_by_line[4] == nil)

  -- Line 5: /review mid-line after space → should be highlighted
  check("/review mid-line highlighted", hl_by_line[5] and #hl_by_line[5] > 0)

  -- Line 6: email@test.com → should NOT highlight (@ is mid-word)
  check("email@ not highlighted", hl_by_line[6] == nil)

  vim.api.nvim_buf_delete(buf, { force = true })
end

print("\n=== highlight: clear and reapply ===")

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "/commit test" })

  highlight.apply(buf)
  local ns = vim.api.nvim_create_namespace("claude_code_hl")
  local marks_before = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  check("has highlights after apply", #marks_before > 0)

  -- Change content and reapply
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no commands here" })
  highlight.apply(buf)
  local marks_after = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  check("highlights cleared after content change", #marks_after == 0)

  vim.api.nvim_buf_delete(buf, { force = true })
end

print("\n=== highlight: edge cases ===")

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "/",           -- bare slash, no name
    "//double",    -- double slash
    "@",           -- bare @
    "",            -- empty line
    "  /compact",  -- indented known skill
  })

  highlight.apply(buf)
  local ns = vim.api.nvim_create_namespace("claude_code_hl")
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })

  local hl_by_line = {}
  for _, mark in ipairs(marks) do
    local row = mark[2]
    hl_by_line[row] = hl_by_line[row] or {}
    hl_by_line[row][#hl_by_line[row] + 1] = mark[4].hl_group
  end

  check("bare / not highlighted", hl_by_line[0] == nil)
  check("empty line not highlighted", hl_by_line[3] == nil)
  check("indented /compact highlighted", hl_by_line[4] and #hl_by_line[4] > 0)

  vim.api.nvim_buf_delete(buf, { force = true })
end

print(("\n  Results: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
  vim.cmd("cq 1")
end
