--- Smart paste: auto-detect content type and wrap appropriately.
--- Code → fenced code block with language detection
--- URL → markdown link
--- Long text → blockquote
local M = {}

local LANG_PATTERNS = {
  -- Shebang detection
  { pattern = "^#!.-/bash",    lang = "bash" },
  { pattern = "^#!.-/sh",     lang = "sh" },
  { pattern = "^#!.-/python", lang = "python" },
  { pattern = "^#!.-/node",   lang = "javascript" },
  { pattern = "^#!.-/env%s+(%w+)", lang_capture = true },

  -- Language-specific keywords/syntax (check first non-empty line)
  { pattern = "^import%s+.+from%s+['\"]", lang = "typescript" },
  { pattern = "^export%s+", lang = "typescript" },
  { pattern = "^const%s+%w+%s*[=:]", lang = "typescript" },
  { pattern = "^function%s+%w+", lang = "javascript" },
  { pattern = "^class%s+%w+", lang = "typescript" },
  { pattern = "^interface%s+%w+", lang = "typescript" },
  { pattern = "^type%s+%w+%s*=", lang = "typescript" },
  { pattern = "^def%s+%w+", lang = "python" },
  { pattern = "^from%s+%w+%s+import", lang = "python" },
  { pattern = "^package%s+%w+", lang = "go" },
  { pattern = "^func%s+", lang = "go" },
  { pattern = "^use%s+%w+", lang = "rust" },
  { pattern = "^fn%s+%w+", lang = "rust" },
  { pattern = "^pub%s+fn%s+", lang = "rust" },
  { pattern = "^require%s*%(?['\"]", lang = "lua" },
  { pattern = "^local%s+%w+%s*=", lang = "lua" },
  { pattern = "^<%?php", lang = "php" },
  { pattern = "^<template>", lang = "vue" },
  { pattern = "^<script", lang = "html" },
  { pattern = "^<!DOCTYPE", lang = "html" },
  { pattern = "^%-%-%- ", lang = "sql" },
  { pattern = "^SELECT%s+", lang = "sql" },
  { pattern = "^CREATE%s+TABLE", lang = "sql" },
  { pattern = "^%$%s", lang = "bash" },
  { pattern = "^{%s*$", lang = "json" },
  { pattern = "^%[%s*$", lang = "json" },
  { pattern = "^apiVersion:", lang = "yaml" },
  { pattern = "^kind:", lang = "yaml" },
  { pattern = "^FROM%s+%w+", lang = "dockerfile" },
  { pattern = "^RUN%s+", lang = "dockerfile" },
}

--- Detect the language of a code snippet.
--- @param text string
--- @return string|nil language identifier
local function detect_language(text)
  local first_line = ""
  for line in text:gmatch("[^\r\n]+") do
    if line:match("%S") then
      first_line = line
      break
    end
  end

  for _, p in ipairs(LANG_PATTERNS) do
    if p.lang_capture then
      local lang = first_line:match(p.pattern)
      if lang then return lang end
    elseif first_line:match(p.pattern) then
      return p.lang
    end
  end

  return nil
end

--- Check if text looks like code (heuristic).
--- @param text string
--- @return boolean
local function looks_like_code(text)
  local lines = vim.split(text, "\n")
  local code_signals = 0

  for _, line in ipairs(lines) do
    if line:match("^%s*[{}%[%]%(%)%;]") then code_signals = code_signals + 1 end
    if line:match("^%s*//") or line:match("^%s*#") or line:match("^%s*%-%-") then code_signals = code_signals + 1 end
    if line:match("^%s+%w+%s*[=:]") then code_signals = code_signals + 1 end
    if line:match("=>") or line:match("->") then code_signals = code_signals + 1 end
  end

  return code_signals >= 2 or detect_language(text) ~= nil
end

--- Check if text is a URL.
--- @param text string
--- @return boolean
local function is_url(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed:match("^https?://") ~= nil and not trimmed:match("%s")
end

--- Format pasted text with smart wrapping.
--- @param text string Raw pasted text
--- @return string[] lines Formatted lines to insert
function M.format(text)
  if not text or text == "" then
    return { text }
  end

  local trimmed = text:gsub("%s+$", "")

  -- Single-line URL → markdown link
  if is_url(trimmed) and not trimmed:match("\n") then
    return { "[" .. trimmed .. "](" .. trimmed .. ")" }
  end

  -- Code detection → fenced code block
  if looks_like_code(trimmed) then
    local lang = detect_language(trimmed) or ""
    local lines = { "```" .. lang }
    for line in trimmed:gmatch("([^\n]*)\n?") do
      lines[#lines + 1] = line
    end
    -- Remove trailing empty line if present
    if lines[#lines] == "" then
      lines[#lines] = nil
    end
    lines[#lines + 1] = "```"
    return lines
  end

  -- Multi-line text (>3 lines) → blockquote
  local line_count = select(2, trimmed:gsub("\n", "")) + 1
  if line_count > 3 then
    local lines = {}
    for line in trimmed:gmatch("([^\n]*)\n?") do
      lines[#lines + 1] = "> " .. line
    end
    if lines[#lines] == "> " then
      lines[#lines] = nil
    end
    return lines
  end

  -- Short text → pass through unchanged
  return vim.split(trimmed, "\n")
end

--- Set up the paste autocmd for a buffer.
--- Intercepts paste and applies smart formatting.
--- @param bufnr number
function M.attach(bufnr)
  vim.keymap.set("n", "p", function()
    local reg = vim.fn.getreg("+")
    if reg == "" then
      reg = vim.fn.getreg('"')
    end

    local formatted = M.format(reg)

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, formatted)
    vim.api.nvim_win_set_cursor(0, { row + #formatted, 0 })
  end, { buffer = bufnr, desc = "Smart paste (auto-fence code, link URLs)" })
end

return M
