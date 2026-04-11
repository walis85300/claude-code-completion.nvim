--- Section navigator: jump between headings in the prompt buffer.
--- Uses fzf-lua if available, falls back to a simple vim.ui.select picker.
local M = {}

--- Extract markdown headings from a buffer.
--- @param bufnr number
--- @return { line: number, level: number, text: string }[]
function M.get_headings(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local headings = {}

  for i, line in ipairs(lines) do
    local hashes, text = line:match("^(#+)%s+(.+)")
    if hashes then
      headings[#headings + 1] = {
        line = i,
        level = #hashes,
        text = text,
      }
    end
  end

  return headings
end

--- Open the section navigator.
--- @param bufnr number|nil
function M.open(bufnr)
  bufnr = bufnr or 0
  local headings = M.get_headings(bufnr)

  if #headings == 0 then
    vim.notify("No headings found in this buffer", vim.log.levels.INFO)
    return
  end

  -- Try fzf-lua first
  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    local display_lines = {}
    local line_lookup = {}

    for _, h in ipairs(headings) do
      local indent = string.rep("  ", h.level - 1)
      local display = string.format("%s%s %s", indent, string.rep("#", h.level), h.text)
      display_lines[#display_lines + 1] = display
      line_lookup[display] = h.line
    end

    fzf.fzf_exec(display_lines, {
      prompt = "Sections> ",
      winopts = {
        title = " Navigate Sections ",
        title_pos = "center",
        height = 0.4,
        width = 0.6,
        preview = { hidden = "hidden" },
      },
      actions = {
        ["default"] = function(selected)
          if selected and #selected > 0 then
            local target_line = line_lookup[selected[1]]
            if target_line then
              vim.api.nvim_win_set_cursor(0, { target_line, 0 })
              vim.cmd("normal! zz")
            end
          end
        end,
      },
    })
    return
  end

  -- Fallback: vim.ui.select
  local items = {}
  local line_map = {}
  for _, h in ipairs(headings) do
    local indent = string.rep("  ", h.level - 1)
    local label = string.format("%s%s %s  (line %d)", indent, string.rep("#", h.level), h.text, h.line)
    items[#items + 1] = label
    line_map[label] = h.line
  end

  vim.ui.select(items, { prompt = "Jump to section:" }, function(choice)
    if choice then
      local target_line = line_map[choice]
      if target_line then
        vim.api.nvim_win_set_cursor(0, { target_line, 0 })
        vim.cmd("normal! zz")
      end
    end
  end)
end

--- Jump to the next heading.
--- @param bufnr number|nil
function M.next(bufnr)
  bufnr = bufnr or 0
  local headings = M.get_headings(bufnr)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  for _, h in ipairs(headings) do
    if h.line > cursor_line then
      vim.api.nvim_win_set_cursor(0, { h.line, 0 })
      vim.cmd("normal! zz")
      return
    end
  end
  vim.notify("No more sections below", vim.log.levels.INFO)
end

--- Jump to the previous heading.
--- @param bufnr number|nil
function M.prev(bufnr)
  bufnr = bufnr or 0
  local headings = M.get_headings(bufnr)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  for i = #headings, 1, -1 do
    if headings[i].line < cursor_line then
      vim.api.nvim_win_set_cursor(0, { headings[i].line, 0 })
      vim.cmd("normal! zz")
      return
    end
  end
  vim.notify("No more sections above", vim.log.levels.INFO)
end

return M
