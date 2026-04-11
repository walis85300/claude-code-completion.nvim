--- blink.cmp custom source for Claude Code skill completion.
--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

--- Only enable in Claude Code prompt buffers.
function source:enabled()
  local bufname = vim.api.nvim_buf_get_name(0)
  local filename = vim.fn.fnamemodify(bufname, ":t")
  return filename:match("^claude%-prompt%-") ~= nil
end

--- Trigger on `/` character.
function source:get_trigger_characters()
  return { "/" }
end

--- Provide completions from scanned skills.
function source:get_completions(ctx, callback)
  local line = ctx.line
  local col = ctx.cursor[2] -- 0-indexed column

  -- Find the `/` that started this completion.
  -- Only trigger at line start or after whitespace.
  local slash_col = nil
  for i = col, 1, -1 do
    local ch = line:sub(i, i)
    if ch == "/" then
      -- Check that the char before `/` is whitespace or start of line
      if i == 1 or line:sub(i - 1, i - 1):match("%s") then
        slash_col = i
      end
      break
    elseif ch:match("%s") then
      break
    end
  end

  if not slash_col then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local scanner = require("claude-code-completion.scanner")
  local skills = scanner.get_skills()

  local kind = 14 -- Keyword
  local ok, types = pcall(require, "blink.cmp.types")
  if ok and types.CompletionItemKind then
    kind = types.CompletionItemKind.Keyword
  end

  --- @type lsp.CompletionItem[]
  local items = {}

  for _, skill in ipairs(skills) do
    local label = "/" .. skill.name

    --- @type lsp.CompletionItem
    local item = {
      label = label,
      kind = kind,
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

    table.insert(items, item)
  end

  callback({
    items = items,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

return source
