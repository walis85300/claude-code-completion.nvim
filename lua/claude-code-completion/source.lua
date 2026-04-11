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
  return require("claude-code-completion.buffer").is_claude_buffer()
end

function source:get_trigger_characters()
  return { "/", ":", "@" }
end

--- Build skill completion items for `/` trigger.
--- @param ctx table blink.cmp context
--- @param slash_col number 1-indexed column of the `/`
--- @return lsp.CompletionItem[]
local function build_skill_items(ctx, slash_col)
  local scanner = require("claude-code-completion.scanner")
  local items = {}

  for _, skill in ipairs(scanner.get_skills()) do
    local label = "/" .. skill.name
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

--- Build file completion items for `@` trigger.
--- @param ctx table blink.cmp context
--- @param at_col number 1-indexed column of the `@`
--- @return lsp.CompletionItem[]
local function build_file_items(ctx, at_col)
  local files_mod = require("claude-code-completion.files")
  local _, prefix = files_mod.find_at_col(ctx.line, ctx.cursor[2])
  local entries = files_mod.get_files(prefix)
  local items = {}

  for _, entry in ipairs(entries) do
    local label = "@" .. entry.path
    local kind = entry.is_dir and CompletionItemKind.Folder or CompletionItemKind.File
    items[#items + 1] = {
      label = label,
      kind = kind,
      filterText = entry.path,
      sortText = entry.is_dir and ("0" .. entry.path) or ("1" .. entry.path),
      detail = entry.is_dir and "directory" or "file",
      textEdit = {
        newText = label,
        range = {
          start = { line = ctx.cursor[1] - 1, character = at_col - 1 },
          ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
        },
      },
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
      items = build_file_items(ctx, at_col),
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
