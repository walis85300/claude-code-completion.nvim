--- blink.cmp custom source for Claude Code prompt completion.
--- Handles two trigger contexts:
---   `/` → skill/command completion
---   `@` → file reference completion
--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local CompletionItemKind = { Keyword = 14, File = 17, Folder = 19 }

local ok, types = pcall(require, "blink.cmp.types")
if ok and types and types.CompletionItemKind then
  CompletionItemKind = types.CompletionItemKind
end

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

function source:enabled()
  return require("claude-code-completion.buffer").get_host() ~= nil
end

function source:get_trigger_characters()
  return { "/", ":", "@" }
end

--- Build skill completion items for `/` trigger.
--- @param ctx table blink.cmp context
--- @param slash_col number 1-indexed column of the `/`
--- @return lsp.CompletionItem[]
local function build_skill_items(ctx, slash_col)
  local host = require('claude-code-completion.buffer').get_host()
  local skills = host == 'pi' and require('claude-code-completion.pi').get_skills()
    or require('claude-code-completion.scanner').get_skills()
  local items = {}

  for _, skill in ipairs(skills) do
    local label = (host == 'pi' and '/skill:' or '/') .. skill.name
    items[#items + 1] = {
      label = label,
      kind = CompletionItemKind.Keyword,
      filterText = skill.name,
      sortText = skill.name,
      detail = "[" .. skill.source .. "]",
      documentation = {
        kind = "markdown",
        value = skill.description ~= "" and skill.description or ("Claude Code skill: `" .. label .. "`"),
      },
      textEdit = {
        newText = label,
        range = {
          start = { line = ctx.cursor[1] - 1, character = slash_col - 1 },
          ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
        },
      },
    }
  end

  return items
end

--- Build @ completion items: agents first, then files.
--- @param ctx table blink.cmp context
--- @param at_col number 1-indexed column of the `@`
--- @return lsp.CompletionItem[]
local function build_at_items(ctx, at_col)
  local files_mod = require("claude-code-completion.files")
  local host = require('claude-code-completion.buffer').get_host()
  local agents_mod = require("claude-code-completion.agents")
  local _, prefix = files_mod.find_at_col(ctx.line, ctx.cursor[2])
  local items = {}
  local edit_range = {
    start = { line = ctx.cursor[1] - 1, character = at_col - 1 },
    ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
  }

  -- Agents (@agent-name)
  for _, agent in ipairs(host == 'pi' and {} or agents_mod.get_agents()) do
    local label = "@" .. agent.name
    items[#items + 1] = {
      label = label,
      kind = CompletionItemKind.Reference or 18,
      filterText = agent.name,
      sortText = "0" .. agent.name, -- agents before files
      detail = "[" .. agent.source .. " agent]",
      documentation = {
        kind = "markdown",
        value = agent.description,
      },
      textEdit = { newText = label, range = edit_range },
    }
  end

  -- Files (@path/to/file)
  local entries = files_mod.get_files(prefix)
  for _, entry in ipairs(entries) do
    local label = "@" .. entry.path
    local kind = entry.is_dir and CompletionItemKind.Folder or CompletionItemKind.File
    items[#items + 1] = {
      label = label,
      kind = kind,
      filterText = entry.path,
      sortText = entry.is_dir and ("1" .. entry.path) or ("2" .. entry.path),
      detail = entry.is_dir and "directory" or "file",
      textEdit = { newText = label, range = edit_range },
    }
  end

  return items
end

function source:get_completions(ctx, callback)
  local line = ctx.line
  local col = ctx.cursor[2]

  -- Check for @ file reference first
  local files_mod = require("claude-code-completion.files")
  local at_col = files_mod.find_at_col(line, col)
  if at_col then
    callback({
      items = build_at_items(ctx, at_col),
      is_incomplete_forward = true,
      is_incomplete_backward = true,
    })
    return
  end

  -- Check for / skill/command
  local buffer = require("claude-code-completion.buffer")
  local slash_col = buffer.find_slash_col(line, col)
  if slash_col then
    callback({
      items = build_skill_items(ctx, slash_col),
      is_incomplete_forward = true,
      is_incomplete_backward = true,
    })
    return
  end

  callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
end

return source
