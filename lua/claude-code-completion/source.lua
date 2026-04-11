--- blink.cmp custom source for Claude Code skill completion.
--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local COMPLETION_KIND_KEYWORD = 14

--- Resolve CompletionItemKind.Keyword once at load time.
local ok, types = pcall(require, "blink.cmp.types")
if ok and types and types.CompletionItemKind then
  COMPLETION_KIND_KEYWORD = types.CompletionItemKind.Keyword
end

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

--- Only enable in Claude Code prompt buffers.
function source:enabled()
  return require("claude-code-completion").is_claude_buffer()
end

--- Trigger on `/` character.
function source:get_trigger_characters()
  return { "/" }
end

--- Provide completions from scanned skills.
function source:get_completions(ctx, callback)
  local line = ctx.line
  local col = ctx.cursor[2] -- 0-indexed column

  local slash_col = require("claude-code-completion").find_slash_col(line, col)

  if not slash_col then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local scanner = require("claude-code-completion.scanner")
  --- @type lsp.CompletionItem[]
  local items = {}

  for _, skill in ipairs(scanner.get_skills()) do
    local label = "/" .. skill.name
    items[#items + 1] = {
      label = label,
      kind = COMPLETION_KIND_KEYWORD,
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
          ["end"] = { line = ctx.cursor[1] - 1, character = col },
        },
      },
    }
  end

  callback({
    items = items,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

return source
