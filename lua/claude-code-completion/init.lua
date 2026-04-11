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

--- @type claude_code.Config|nil
local config = nil
local setup_done = false

--- @return claude_code.Config
function M.get_config()
  return config or defaults
end

--- Check if a buffer is a Claude Code prompt file.
--- @param bufnr number
--- @return boolean
function M.is_claude_buffer(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local filename = vim.fn.fnamemodify(bufname, ":t")
  return filename:match("^claude%-prompt%-") ~= nil
end

--- Omnifunc for buffers without blink.cmp.
--- @param findstart number
--- @param base string
--- @return number|table
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".") - 1

    -- Walk back to find the `/`
    for i = col, 1, -1 do
      local ch = line:sub(i, i)
      if ch == "/" then
        if i == 1 or line:sub(i - 1, i - 1):match("%s") then
          return i - 1 -- 0-indexed
        end
        return -3
      elseif ch:match("%s") then
        return -3
      end
    end
    return -3
  end

  local scanner = require("claude-code-completion.scanner")
  local skills = scanner.get_skills()
  local items = {}

  for _, skill in ipairs(skills) do
    local label = "/" .. skill.name
    if label:find(base, 1, true) == 1 or base == "" then
      table.insert(items, {
        word = label,
        abbr = label,
        menu = "[" .. skill.source .. "]",
        info = skill.description,
      })
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

  -- Register blink.cmp provider if available
  local has_blink = pcall(require, "blink.cmp")
  if has_blink then
    -- Merge our source into blink.cmp config via lazy.nvim opts pattern.
    -- This works because lazy.nvim deep-merges opts tables.
    -- For users configuring blink.cmp manually, they can add the provider themselves.
    local ok_blink, blink = pcall(require, "blink.cmp")
    if ok_blink and blink and blink.add_provider then
      -- blink.cmp >= v1 supports add_provider
      blink.add_provider("claude_code", {
        name = "Claude Code",
        module = "claude-code-completion.source",
        score_offset = 100, -- high priority in Claude buffers
      })
    end
  end

  -- Create autocmd group
  local group = vim.api.nvim_create_augroup("ClaudeCodeCompletion", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function(ev)
      if not M.is_claude_buffer(ev.buf) then
        return
      end

      -- Refresh scanner cache on each buffer enter (manifest may have been updated)
      local scanner = require("claude-code-completion.scanner")
      scanner.refresh()

      -- Set omnifunc as fallback if blink.cmp is not available
      if not pcall(require, "blink.cmp") then
        vim.bo[ev.buf].omnifunc = "v:lua.require'claude-code-completion'.omnifunc"
      end
    end,
  })

  -- User command to refresh skills cache
  vim.api.nvim_create_user_command("ClaudeSkillsRefresh", function()
    local scanner = require("claude-code-completion.scanner")
    scanner.refresh()
    local skills = scanner.get_skills()
    vim.notify(string.format("Claude Code: refreshed %d skills", #skills), vim.log.levels.INFO)
  end, { desc = "Refresh Claude Code skills cache" })
end

return M
