--- Smart paste: auto-detect content type and wrap appropriately.
--- Code → fenced code block (language via vim.filetype.match + fallback heuristics)
--- URL → markdown link
--- Long text (>3 lines) → blockquote
local M = {}

-- Fallback patterns for short snippets that vim.filetype.match misses.
-- Only the most common languages — vim.filetype handles the long tail.
local FALLBACK = {
  { "^import%s+.+from%s+['\"]", "typescript" },
  { "^export%s+", "typescript" },
  { "^const%s+%w+%s*[=:]", "typescript" },
  { "^interface%s+%w+", "typescript" },
  { "^type%s+%w+%s*=", "typescript" },
  { "^def%s+%w+", "python" },
  { "^from%s+%w+%s+import", "python" },
  { "^package%s+%w+", "go" },
  { "^func%s+", "go" },
  { "^fn%s+%w+", "rust" },
  { "^pub%s+fn", "rust" },
  { "^local%s+%w+%s*=", "lua" },
  { "^SELECT%s+", "sql" },
  { "^CREATE%s+TABLE", "sql" },
  { "^FROM%s+%w+", "dockerfile" },
  { "^RUN%s+", "dockerfile" },
  { "^{%s*$", "json" },
}

--- @param text string
--- @return string|nil
local function detect_language(text)
  local lines = vim.split(text, "\n")

  -- Try nvim's built-in filetype detection first (treesitter + heuristics)
  local ft = vim.filetype.match({ contents = lines })
  if ft and ft ~= "" then return ft end

  -- Fallback: match first non-empty line against common patterns
  local first = ""
  for _, line in ipairs(lines) do
    if line:match("%S") then first = line; break end
  end
  for _, entry in ipairs(FALLBACK) do
    if first:match(entry[1]) then return entry[2] end
  end

  return nil
end

--- @param text string
--- @return string[]
local function wrap_code(text, lang)
  local result = { "```" .. (lang or "") }
  vim.list_extend(result, vim.split(text, "\n"))
  if result[#result] == "" then result[#result] = nil end
  result[#result + 1] = "```"
  return result
end

--- @param text string
--- @return string[]
local function wrap_blockquote(text)
  local lines = {}
  for _, line in ipairs(vim.split(text, "\n")) do
    lines[#lines + 1] = "> " .. line
  end
  if lines[#lines] == "> " then lines[#lines] = nil end
  return lines
end

--- Format pasted text with smart wrapping.
--- @param text string
--- @return string[]
function M.format(text)
  if not text or text == "" then return { text } end

  local trimmed = text:gsub("%s+$", "")

  -- URL → markdown link
  if trimmed:match("^https?://") and not trimmed:match("[%s\n]") then
    return { ("[%s](%s)"):format(trimmed, trimmed) }
  end

  -- Code → fenced block
  local lang = detect_language(trimmed)
  if lang then return wrap_code(trimmed, lang) end

  -- Long text → blockquote
  if select(2, trimmed:gsub("\n", "")) >= 3 then
    return wrap_blockquote(trimmed)
  end

  return vim.split(trimmed, "\n")
end

--- Attach smart paste keymap to a buffer.
--- @param bufnr number
function M.attach(bufnr)
  vim.keymap.set("n", "p", function()
    local reg = vim.fn.getreg("+")
    if reg == "" then reg = vim.fn.getreg('"') end
    local formatted = M.format(reg)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, formatted)
    vim.api.nvim_win_set_cursor(0, { row + #formatted, 0 })
  end, { buffer = bufnr, desc = "Smart paste" })
end

return M
