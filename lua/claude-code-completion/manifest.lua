--- Manifest generator — entry point for the SessionStart hook.
--- Called via: nvim --headless --clean --cmd "set rtp+=<plugin>" -l manifest.lua
--- Reads hook JSON from stdin, scans all skill sources, writes manifest to $TMPDIR.
--- Reuses the plugin's own builtins, frontmatter parser, and scan logic — zero duplication.

local builtins = require("claude-code-completion.builtins")
local frontmatter = require("claude-code-completion.frontmatter")

-- --- Portable helpers ---

local function get_tmpdir()
  local tmpdir = vim.uv.os_getenv("TMPDIR")
  if tmpdir and tmpdir ~= "" then
    return tmpdir:gsub("/$", "")
  end
  return "/tmp"
end

local function sha256_short(str)
  return vim.fn.sha256(str):sub(1, 12)
end

--- Scan a directory for skills (flat *.md + nested <name>/SKILL.md).
--- @param dir string
--- @param source string
--- @return table[]
local function scan_dir(dir, source)
  local skills = {}
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then
    return skills
  end

  -- Flat: dir/*.md
  for _, filepath in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(filepath)
    if parsed then
      skills[#skills + 1] = { name = parsed.name, description = parsed.description, source = source }
    end
  end

  -- Nested: dir/<name>/SKILL.md
  for _, skill_file in ipairs(vim.fn.glob(dir .. "/*/SKILL.md", false, true)) do
    local parsed = frontmatter.parse_skill_file(skill_file)
    if parsed then
      local name = (parsed.name == "SKILL" or parsed.name == "") and vim.fn.fnamemodify(skill_file, ":h:t") or parsed.name
      skills[#skills + 1] = { name = name, description = parsed.description, source = source }
    end
  end

  return skills
end

-- --- Read CWD from hook stdin ---

local cwd = vim.uv.cwd() or vim.fn.getcwd()

-- Hook passes JSON on stdin with { "cwd": "..." }
local stdin = vim.uv.new_pipe()
stdin:open(0)
local stdin_data = ""
stdin:read_start(function(err, data)
  if data then
    stdin_data = stdin_data .. data
  else
    stdin:read_stop()
    stdin:close()
  end
end)

-- Give stdin a moment to drain, then process
vim.defer_fn(function()
  if stdin_data ~= "" then
    local ok, input = pcall(vim.json.decode, stdin_data)
    if ok and input and input.cwd then
      cwd = input.cwd
    end
  end

  local home = vim.uv.os_homedir() or vim.fn.expand("~")
  local claude_dir = home .. "/.claude"
  local skills = {}

  -- 1. Builtins
  vim.list_extend(skills, builtins.get())

  -- 2. User skills
  vim.list_extend(skills, scan_dir(claude_dir .. "/skills", "user"))

  -- 3. Project skills (CWD-dependent)
  vim.list_extend(skills, scan_dir(cwd .. "/.claude/skills", "project"))

  -- 4. Plugin skills (cache + marketplaces)
  local skill_dirs = vim.fn.glob(claude_dir .. "/plugins/cache/*/*/*/skills", false, true)
  vim.list_extend(skill_dirs, vim.fn.glob(claude_dir .. "/plugins/marketplaces/*/plugins/*/skills", false, true))
  for _, sdir in ipairs(skill_dirs) do
    vim.list_extend(skills, scan_dir(sdir, "plugin"))
  end

  -- Write manifest
  local tmpdir = get_tmpdir()
  local manifest_path = tmpdir .. "/claude-skills-" .. sha256_short(cwd) .. ".json"
  local latest_path = tmpdir .. "/claude-skills-latest.json"

  local manifest = {
    version = 1,
    cwd = cwd,
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    skills = skills,
  }

  local content = vim.json.encode(manifest)

  local f = io.open(manifest_path, "w")
  if f then
    f:write(content)
    f:close()
  end

  local f2 = io.open(latest_path, "w")
  if f2 then
    f2:write(content)
    f2:close()
  end

  vim.cmd("qa!")
end, 10)
