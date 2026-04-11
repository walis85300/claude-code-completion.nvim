--- Buffer detection for Claude Code prompt files.
local M = {}

local CLAUDE_PROMPT_PATTERN = "^claude%-prompt%-"

--- Check if a buffer is a Claude Code prompt file.
--- @param bufnr number|nil Buffer number (0 or nil for current)
--- @return boolean
function M.is_claude_buffer(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  return vim.fn.fnamemodify(name, ":t"):match(CLAUDE_PROMPT_PATTERN) ~= nil
end

--- Find the slash-command start column in a line, or nil if not valid.
--- Valid positions: line start or after whitespace.
--- @param line string
--- @param col number 1-indexed cursor column
--- @return number|nil 1-indexed column of the `/`
function M.find_slash_col(line, col)
  for i = col, 1, -1 do
    local ch = line:sub(i, i)
    if ch == "/" then
      if i == 1 or line:sub(i - 1, i - 1):match("%s") then
        return i
      end
      return nil
    elseif ch:match("%s") then
      return nil
    end
  end
  return nil
end

return M
