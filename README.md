# claude-code-completion.nvim

Autocomplete for Claude Code skills and slash commands when editing prompts via `Ctrl+G`.

When you press `Ctrl+G` in Claude Code, it opens your `$EDITOR` with a temp file. This plugin detects those buffers and provides completion for `/slash-commands` via [blink.cmp](https://github.com/saghen/blink.cmp) (LazyVim's default completion engine).

## Features

- Autocomplete for 50+ built-in commands and bundled skills
- Dynamic discovery of user skills (`~/.claude/skills/`)
- Dynamic discovery of project skills (`.claude/skills/`)
- Dynamic discovery of plugin skills (`~/.claude/plugins/`)
- **SessionStart hook** for project-aware skill manifests (recommended)
- Falls back to filesystem scan when no hook manifest exists
- Omnifunc fallback for non-blink.cmp setups
- Zero dependencies beyond Neovim 0.10+

## Installation

### lazy.nvim (recommended)

```lua
{
  "eduardoalva/claude-code-completion.nvim",
  event = "BufEnter",
  opts = {},
}
```

### With blink.cmp provider registration

For best results, also register the source in your blink.cmp config:

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

For the most complete skill discovery, install the included hook script. It runs on every Claude Code session start and writes a JSON manifest that the plugin reads:

1. Make the script available in your `$PATH`:

```bash
# Option A: symlink
ln -s "$(find ~/.local/share/nvim/lazy/claude-code-completion.nvim/bin -name claude-skills-manifest)" ~/.local/bin/claude-skills-manifest

# Option B: copy
cp ~/.local/share/nvim/lazy/claude-code-completion.nvim/bin/claude-skills-manifest ~/.local/bin/
```

2. Add the hook to your Claude Code `settings.json`:

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

The hook requires [Bun](https://bun.sh). It scans all skill sources in Claude Code's CWD context and writes a manifest to `/tmp/claude-skills-*.json`.

Without the hook, the plugin falls back to scanning skill directories from nvim using the inherited CWD.

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

- `:ClaudeSkillsRefresh` - Clear cache and rescan skills
- `:checkhealth claude-code-completion` - Verify setup

## How It Works

```
Claude Code (Ctrl+G)
    |
    v
Opens $EDITOR with /tmp/claude-prompt-{uuid}.md
    |
    v
Plugin detects buffer name pattern
    |
    v
Reads SessionStart hook manifest (or scans filesystem)
    |
    v
blink.cmp shows completions when you type "/"
```

## Skill Sources (priority order)

| Source | Location | Method |
|--------|----------|--------|
| Hook manifest | `/tmp/claude-skills-*.json` | Written by SessionStart hook |
| Built-in commands | Hardcoded in plugin | Always available |
| User skills | `~/.claude/skills/*.md` | Frontmatter parsed |
| Project skills | `.claude/skills/*.md` | Frontmatter parsed |
| Plugin skills | `~/.claude/plugins/*/skills/*.md` | Frontmatter parsed |

## License

MIT
