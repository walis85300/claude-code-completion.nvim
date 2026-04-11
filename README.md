# claude-code-completion.nvim

Skill and slash-command autocomplete for Neovim inside Claude Code's `Ctrl+G` editor.

Claude Code has 50+ built-in commands, bundled skills, and hundreds of plugin-provided skills. When `Ctrl+G` opens your editor, you're on your own remembering them. This plugin brings them all into your completion menu.

It detects Claude Code's temp prompt buffers, discovers every available skill (built-in, user, project, and plugin), and feeds them to [blink.cmp](https://github.com/saghen/blink.cmp) — the default completion engine in LazyVim. Type `/` and see everything.

## Features

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
  },
  opts = {},
}
```

The plugin ships with [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) as a dependency — Claude Code prompts are always `.md` files, so you get rendered headings, bullets, tables, and checkboxes out of the box.

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
| `:ClaudeSkillsRefresh` | Clear cache and rescan skills |
| `:checkhealth claude-code-completion` | Verify setup |

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
