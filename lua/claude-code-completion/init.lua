--- claude-code-completion.nvim
--- Autocomplete for Claude Code skills/slash commands in the Ctrl+G editor.
local M = {}

--- @class claude_code.Config
--- @field scan_paths { user: boolean, project: boolean, plugins: boolean }

--- @type claude_code.Config
local defaults = {
  scan_paths = {
    user = true,
    project = true,
    plugins = true,
  },
}

--- @type claude_code.Config
local config = defaults
local setup_done = false

local CLAUDE_PROMPT_PATTERN = "^claude%-prompt%-"

--- @return claude_code.Config
function M.get_config()
  return config
end

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

--- Omnifunc for buffers without blink.cmp.
--- @param findstart number
--- @param base string
--- @return number|table
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".") - 1
    local slash_col = M.find_slash_col(line, col)
    return slash_col and (slash_col - 1) or -3
  end

  local scanner = require("claude-code-completion.scanner")
  local items = {}
  for _, skill in ipairs(scanner.get_skills()) do
    local label = "/" .. skill.name
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

--- Set up the plugin.
--- @param opts claude_code.Config|nil
function M.setup(opts)
  if setup_done then
    return
  end
  setup_done = true

  config = vim.tbl_deep_extend("force", defaults, opts or {})

  local group = vim.api.nvim_create_augroup("ClaudeCodeCompletion", { clear = true })

  local last_refresh = 0
  local REFRESH_TTL_SEC = 5

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function(ev)
      if not M.is_claude_buffer(ev.buf) then
        return
      end

      local now = vim.uv.now() / 1000
      if (now - last_refresh) > REFRESH_TTL_SEC then
        require("claude-code-completion.scanner").refresh()
        last_refresh = now
      end

      if not pcall(require, "blink.cmp") then
        vim.bo[ev.buf].omnifunc = "v:lua.require'claude-code-completion'.omnifunc"
      end
    end,
  })

  vim.api.nvim_create_user_command("ClaudeSkillsRefresh", function()
    local scanner = require("claude-code-completion.scanner")
    scanner.refresh()
    local count = #scanner.get_skills()
    vim.notify(("Claude Code: refreshed %d skills"):format(count), vim.log.levels.INFO)
  end, { desc = "Refresh Claude Code skills cache" })
end

--- Reset state (for testing).
--- @private
function M._reset()
  setup_done = false
  config = defaults
end

return M
