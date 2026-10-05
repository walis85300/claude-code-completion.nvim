--- Omnifunc completion fallback for setups without blink.cmp.
local M = {}

local buffer = require("claude-code-completion.buffer")

--- Omnifunc-compatible completion function.
--- @param findstart number
--- @param base string
--- @return number|table
function M.complete(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".") - 1
    local slash_col = buffer.find_slash_col(line, col)
    return slash_col and (slash_col - 1) or -3
  end

  local host = buffer.get_host()
  local skills = host == 'pi' and require('claude-code-completion.pi').get_skills()
    or require('claude-code-completion.scanner').get_skills()
  local items = {}
  for _, skill in ipairs(skills) do
    local label = (host == 'pi' and '/skill:' or '/') .. skill.name
    if base == "" or label:find(base, 1, true) == 1 then
      items[#items + 1] = {
        word = label,
        abbr = label,
        menu = "[" .. skill.source .. "]",
        info = skill.description,
      }
    end
  end
  return items
end

return M
