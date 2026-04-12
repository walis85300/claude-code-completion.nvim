--- Smart paste for Claude Code prompt buffers.
--- URL → markdown link
--- Multiline → fenced code block (language detected via vim.filetype.match)
--- Single line → passthrough
local M = {}

--- @param text string
--- @return string[]
function M.format(text)
  if not text or text == "" then return { text } end

  local trimmed = text:gsub("%s+$", "")

  -- Single-line URL → markdown link
  if trimmed:match("^https?://") and not trimmed:match("[%s\n]") then
    return { ("[%s](%s)"):format(trimmed, trimmed) }
  end

  -- Multiline → fenced code block
  if trimmed:match("\n") then
    local lang = vim.filetype.match({ contents = vim.split(trimmed, "\n") }) or ""
    local result = { "```" .. lang }
    vim.list_extend(result, vim.split(trimmed, "\n"))
    if result[#result] == "" then result[#result] = nil end
    result[#result + 1] = "```"
    return result
  end

  return { trimmed }
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
