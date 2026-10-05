--- Buffer detection for Claude Code prompt files.
local M = {}

local CLAUDE_PROMPT_PATTERN = "^claude%-prompt%-"

--- Identify the external editor host without matching ordinary prompt.md files.
function M.get_host(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local base = vim.fn.fnamemodify(name, ':t')
  if base:match(CLAUDE_PROMPT_PATTERN) then return 'claude' end
  if base == 'prompt.md' and vim.fn.fnamemodify(name, ':h:t'):match('^pi%-editor%-') then return 'pi' end
  return nil
end

--- Check if a buffer is a Claude Code prompt file.
--- @param bufnr number|nil Buffer number (0 or nil for current)
--- @return boolean
function M.is_claude_buffer(bufnr)
  return M.get_host(bufnr) == 'claude'
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
