--- Pi resources for prompts opened via Ctrl+G. No Claude manifest is used.
local M = {}
local discovery = require('claude-code-completion.discovery')
local cache = {}

function M.refresh()
  cache = {}
end

local function agent_dir()
  local path = vim.env.PI_CODING_AGENT_DIR
  return path and path ~= '' and vim.fn.expand(path) or (vim.fn.expand('~/.pi/agent'))
end

local function scan_dirs(dirs, source)
  local items = {}
  for _, dir in ipairs(dirs) do
    vim.list_extend(items, discovery.scan_dir(dir, source))
  end
  return items
end

local function parents(cwd)
  local dirs = {}
  while cwd and cwd ~= '' do
    table.insert(dirs, 1, cwd)
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent == cwd then break end
    cwd = parent
  end
  return dirs
end

function M.get_skills()
  local cwd = discovery.get_cwd()
  if cache.cwd == cwd and cache.skills then return cache.skills end
  if cache.cwd ~= cwd then M.refresh() end
  local items = {}
  local user = agent_dir()
  vim.list_extend(items, scan_dirs({ user .. '/skills', vim.fn.expand('~/.agents/skills') }, 'user'))
  for _, dir in ipairs(parents(discovery.get_cwd())) do
    vim.list_extend(items, scan_dirs({ dir .. '/.pi/skills', dir .. '/.agents/skills' }, 'project'))
  end
  -- Respect explicit skill directories in Pi's user settings (e.g. ~/.claude/skills).
  local f = io.open(user .. '/settings.json', 'r')
  if f then
    local ok, settings = pcall(vim.json.decode, f:read('*a'))
    f:close()
    if ok and type(settings) == 'table' and type(settings.skills) == 'table' then
      for _, path in ipairs(settings.skills) do
        if type(path) == 'string' and not path:match('^[!+-]') and not path:find('*', 1, true) then
          local expanded = vim.fn.expand(path)
          if not path:match('^/') and not path:match('^~') then expanded = user .. '/' .. path end
          vim.list_extend(items, discovery.scan_dir(expanded, 'configured'))
        end
      end
    end
    if ok and type(settings) == 'table' and type(settings.packages) == 'table' then
      for _, package in ipairs(settings.packages) do
        if type(package) == 'string' and package:match('^npm:') then
          local name = package:sub(5):gsub('@[%d%.%-]+$', '')
          local root = user .. '/npm/node_modules/' .. name
          local manifest = io.open(root .. '/package.json', 'r')
          if manifest then
            local valid, data = pcall(vim.json.decode, manifest:read('*a'))
            manifest:close()
            if valid and type(data.pi) == 'table' and type(data.pi.skills) == 'table' then
              for _, dir in ipairs(data.pi.skills) do
                if type(dir) == 'string' and dir:match('^%./[%w_/-]+$') then
                  vim.list_extend(items, discovery.scan_dir(root .. '/' .. dir:sub(3), 'package'))
                end
              end
            end
          end
        end
      end
    end
  end
  cache.cwd = cwd
  cache.skills = discovery.dedupe(items)
  return cache.skills
end

function M.get_agents()
  local cwd = discovery.get_cwd()
  if cache.cwd == cwd and cache.agents then return cache.agents end
  if cache.cwd ~= cwd then M.refresh() end
  local items = {}
  local user = agent_dir()
  -- pi-subagents supplies agents; Pi itself has no native @agent prompt syntax.
  local bundled = user .. '/npm/node_modules/pi-subagents/agents'
  vim.list_extend(items, discovery.scan_dir(bundled, 'package'))
  vim.list_extend(items, discovery.scan_dir(user .. '/agents', 'user'))
  for _, dir in ipairs(parents(discovery.get_cwd())) do
    vim.list_extend(items, scan_dirs({ dir .. '/.agents', dir .. '/.pi/agents' }, 'project'))
  end
  cache.cwd = cwd
  cache.agents = discovery.dedupe(items)
  return cache.agents
end

return M
