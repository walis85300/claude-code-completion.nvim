# claude-code-completion.nvim

Skill and slash-command autocomplete for Neovim inside Claude Code's and Pi's `Ctrl+G` editors.

Claude Code has 50+ built-in commands, bundled skills, and hundreds of plugin-provided skills. When `Ctrl+G` opens your editor, you're on your own remembering them. This plugin brings them all into your completion menu.

It detects Claude Code's temp prompt buffers and Pi's `pi-editor-*/prompt.md` buffers, and feeds their respective skills to [blink.cmp](https://github.com/saghen/blink.cmp) — the default completion engine in LazyVim. Type `/` to see completions.

## Features

### Pi support

Press `Ctrl+G` in Pi with `$EDITOR=nvim`. In the resulting prompt buffer, `/skill:` completes Pi skills, and `@` completes project files. The picker (`<leader>cp`) also lists Pi agents; selecting one inserts a natural-language request (Pi does **not** interpret `@agent` as a native agent invocation). Save and quit Neovim to return the edited draft to Pi.

Pi resource discovery scans `~/.pi/agent/skills`, `~/.agents/skills`, ancestor `.pi/skills` and `.agents/skills`, plus non-glob directories explicitly listed in `~/.pi/agent/settings.json` `skills` and installed npm packages declaring `pi.skills`. Agent discovery scans `~/.pi/agent/agents`, ancestor `.pi/agents` and `.agents` directories, and installed `pi-subagents` bundled agents. The scanner does not enumerate project settings overrides or arbitrary package sources; use Pi's native command picker for the authoritative list. No Claude manifest or Claude-only builtins are used for Pi buffers.


- `/` completion for 50+ built-in commands and bundled skills
- Dynamic discovery from `~/.claude/skills/`, `.claude/skills/`, and `~/.claude/plugins/`
- **SessionStart hook** writes a project-aware manifest — skills reflect the CWD Claude Code is running in
- Filesystem scan fallback when no manifest exists
- Omnifunc fallback for setups without blink.cmp
- Zero external dependencies — only requires Neovim 0.10+
- Works on macOS and Linux

## Installation

### lazy.nvim

```lua
{
  "walis85300/claude-code-completion.nvim",
  event = "BufEnter",
  dependencies = {
    "MeanderingProgrammer/render-markdown.nvim",
    "ibhagwan/fzf-lua",
  },
  opts = {},
}
```

Bundled dependencies:
- [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) — Claude prompts are `.md` files; rendered headings, bullets, tables out of the box
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) — powers the picker for browsing skills, agents, and files with preview

### With blink.cmp provider (recommended)

```lua
{
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "claude_code" },
      providers = {
        claude_code = {
          name = "Claude Code",
          module = "claude-code-completion.source",
          score_offset = 100,
        },
      },
    },
  },
}
```

## SessionStart Hook (recommended)

The hook runs a Lua script via `nvim --headless` on every Claude Code session start. It reuses the plugin's own scanner and frontmatter parser — no external dependencies beyond nvim itself.

### Setup

1. Add the script to your `$PATH`:

```bash
ln -s ~/.local/share/nvim/lazy/claude-code-completion.nvim/bin/claude-skills-manifest ~/.local/bin/
```

2. Add the hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "command": "claude-skills-manifest"
      }
    ]
  }
}
```

The hook scans all skill sources from Claude Code's CWD context and writes a manifest to `$TMPDIR/claude-skills-*.json`. Without it, the plugin falls back to scanning skill directories from nvim using the inherited CWD.

## Configuration

```lua
require("claude-code-completion").setup({
  scan_paths = {
    user = true,    -- ~/.claude/skills/
    project = true, -- {cwd}/.claude/skills/
    plugins = true, -- ~/.claude/plugins/*/skills/
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:ClaudeSkillsRefresh` | Clear cache and rescan skills + agents |
| `:ClaudePicker` | Open fzf picker (all skills, agents, files) |
| `:ClaudePicker /` | Open picker filtered to skills |
| `:ClaudePicker @` | Open picker filtered to agents + files |
| `:checkhealth claude-code-completion` | Verify setup |

## Keybindings (Claude prompt buffers only)

| Mode | Key | Action |
|------|-----|--------|
| Normal | `<leader>/` | Browse skills with fzf preview |
| Normal | `<leader>@` | Browse agents + files with fzf preview |
| Normal | `<leader>cp` | Browse all (skills, agents, files) |
| Insert | `Ctrl+/` | Browse skills (insert mode) |
| Insert | `Ctrl+@` | Browse agents + files (insert mode) |

Selecting an item inserts it at the cursor position (`/skill-name` or `@file-path`).

## Semantic Highlighting

Known skills and agents are highlighted differently from unrecognized ones:

| Pattern | Highlight | Meaning |
|---------|-----------|---------|
| `/commit` | `ClaudeSlashCommand` (keyword color) | Known skill |
| `/typo` | `ClaudeSlashUnknown` (comment/dim) | Not a known skill |
| `@Explore` | `ClaudeAtAgent` (attribute color) | Known agent |
| `@src/file.ts` | `ClaudeAtFile` (string color) | File exists in project |
| `@nonexistent` | `ClaudeAtUnknown` (comment/dim) | Not found |

Highlights update live as you type. Customize with:

```lua
vim.api.nvim_set_hl(0, "ClaudeSlashCommand", { fg = "#ff9e64", bold = true })
vim.api.nvim_set_hl(0, "ClaudeAtAgent", { fg = "#7dcfff", bold = true })
vim.api.nvim_set_hl(0, "ClaudeAtFile", { fg = "#9ece6a" })
```

## How It Works

```
Claude Code (Ctrl+G)
    │
    ▼
Opens $EDITOR with /tmp/claude-prompt-{uuid}.md
    │
    ▼
Plugin detects buffer name ──► Reads hook manifest or scans filesystem
    │
    ▼
blink.cmp shows completions when you type "/"
```

## Skill Sources

| Priority | Source | Location |
|----------|--------|----------|
| 1 | Hook manifest | `$TMPDIR/claude-skills-{hash}.json` |
| 2 | Built-in commands | Hardcoded in plugin |
| 3 | User skills | `~/.claude/skills/*.md` |
| 4 | Project skills | `{cwd}/.claude/skills/*.md` |
| 5 | Plugin skills | `~/.claude/plugins/**/skills/` |

## Running Tests

```bash
make test
```

## License

MIT
