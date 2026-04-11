--- Unified fzf-lua picker for skills, agents, and files.
--- Requires ibhagwan/fzf-lua. Opens a picker with preview and inserts at cursor.
local M = {}

local ICONS = {
  skill_known = "󰘧 ",
  skill_bundled = "󱐋 ",
  agent = "󰚩 ",
  file = "󰈙 ",
  dir = "󰉋 ",
}

--- @class PickerEntry
--- @field display string Formatted display line
--- @field insert string Text to insert at cursor
--- @field preview_path string|nil File path for preview
--- @field preview_text string|nil Inline preview text

--- Build all picker entries.
--- @return PickerEntry[]
local function build_entries()
  local scanner = require("claude-code-completion.scanner")
  local agents = require("claude-code-completion.agents")
  local files_mod = require("claude-code-completion.files")
  local entries = {}

  for _, s in ipairs(scanner.get_skills()) do
    local icon = s.source == "bundled" and ICONS.skill_bundled or ICONS.skill_known
    entries[#entries + 1] = {
      display = string.format("%s/%s  %s  [%s]", icon, s.name, s.description, s.source),
      insert = "/" .. s.name,
      preview_text = s.description ~= "" and s.description or ("Skill: /" .. s.name),
    }
  end

  for _, a in ipairs(agents.get_agents()) do
    entries[#entries + 1] = {
      display = string.format("%s@%s  %s  [%s]", ICONS.agent, a.name, a.description, a.source),
      insert = "@" .. a.name,
      preview_text = a.description,
    }
  end

  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  for _, e in ipairs(files_mod.get_files("")) do
    local icon = e.is_dir and ICONS.dir or ICONS.file
    local full_path = cwd .. "/" .. e.path
    entries[#entries + 1] = {
      display = string.format("%s@%s", icon, e.path),
      insert = "@" .. e.path,
      preview_path = full_path,
    }
  end

  return entries
end

--- Insert text at cursor position in the current buffer.
--- @param text string
local function insert_at_cursor(text)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
  local new_line = line:sub(1, col) .. text .. " " .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { row + 1, col + #text + 1 })
end

--- Open the picker.
--- @param filter string|nil Optional initial query (e.g. "/" or "@")
function M.open(filter)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("claude-code-completion: fzf-lua required (ibhagwan/fzf-lua)", vim.log.levels.WARN)
    return
  end

  local entries = build_entries()
  if #entries == 0 then
    vim.notify("claude-code-completion: no skills, agents, or files found", vim.log.levels.INFO)
    return
  end

  -- Build display lines and lookup table
  local display_lines = {}
  local lookup = {}
  for _, e in ipairs(entries) do
    display_lines[#display_lines + 1] = e.display
    lookup[e.display] = e
  end

  fzf.fzf_exec(display_lines, {
    prompt = "Claude> ",
    query = filter or "",
    winopts = {
      title = " Skills / Agents / Files ",
      title_pos = "center",
      height = 0.6,
      width = 0.8,
      preview = {
        layout = "vertical",
        vertical = "down:40%",
      },
    },
    fzf_opts = {
      ["--no-multi"] = "",
    },
    previewer = {
      _ctor = function()
        local Previewer = require("fzf-lua.previewer.builtin")
        local P = Previewer.buffer_or_file:extend()

        function P:new(o, opts, fzf_win)
          P.super.new(self, o, opts, fzf_win)
          return self
        end

        function P:parse_entry(entry_str)
          local entry = lookup[entry_str]
          if entry and entry.preview_path then
            return { path = entry.preview_path }
          end
          return {}
        end

        function P:populate_preview_buf(entry_str)
          local entry = lookup[entry_str]
          if not entry then return end

          if entry.preview_path then
            -- Use built-in file preview
            P.super.populate_preview_buf(self, entry_str)
          else
            -- Text preview for skills/agents
            local text = entry.preview_text or ""
            local lines = vim.split(text, "\n")
            local buf = self:get_tmp_buffer()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            self:set_preview_buf(buf)
            vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
          end
        end

        return P
      end,
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local entry = lookup[selected[1]]
        if entry then
          insert_at_cursor(entry.insert)
        end
      end,
    },
  })
end

function M.skills()
  M.open("/")
end

function M.mentions()
  M.open("@")
end

return M
