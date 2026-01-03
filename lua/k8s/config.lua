--- config.lua - 設定管理

local M = {}

-- Default keymaps per view type
local default_keymaps = {
  -- Global keymaps (shared across views)
  global = {
    quit = { key = "q", desc = "Hide" },
    close = { key = "<C-c>", desc = "Close" },
    back = { key = "<C-h>", desc = "Back" },
    help = { key = "?", desc = "Help" },
  },
  -- List view keymaps
  list = {
    select = { key = "<CR>", desc = "Select" },
    describe = { key = "d", desc = "Describe" },
    delete = { key = "D", desc = "Delete" },
    logs = { key = "l", desc = "Logs" },
    logs_previous = { key = "P", desc = "PrevLogs" },
    exec = { key = "e", desc = "Exec" },
    scale = { key = "s", desc = "Scale" },
    restart = { key = "X", desc = "Restart" },
    port_forward = { key = "p", desc = "PortFwd" },
    port_forward_list = { key = "F", desc = "PortFwdList" },
    filter = { key = "/", desc = "Filter" },
    refresh = { key = "r", desc = "Refresh" },
    resource_menu = { key = "R", desc = "Resources" },
    context_menu = { key = "C", desc = "Context" },
    namespace_menu = { key = "N", desc = "Namespace" },
  },
  -- Describe view keymaps
  describe = {
    toggle_secret = { key = "S", desc = "ToggleSecret" },
  },
  -- Port forward list view keymaps
  port_forward_list = {
    stop = { key = "D", desc = "Stop" },
  },
  -- Help view keymaps (only navigation, no help key)
  help = {},
}

-- Default configuration
local defaults = {
  timeout = 30000, -- 30 seconds
  default_namespace = "default",
  default_kind = "Pod",
  transparent = false, -- Transparent window background
  keymaps = default_keymaps,
}

---Get default configuration
---@return table
function M.get_defaults()
  return vim.deepcopy(defaults)
end

---Deep merge two tables
---@param t1 table
---@param t2 table
---@return table
local function deep_merge(t1, t2)
  local result = vim.deepcopy(t1)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

---Merge user config with defaults
---@param user_config table|nil
---@return table
function M.merge(user_config)
  if not user_config then
    return M.get_defaults()
  end
  return deep_merge(M.get_defaults(), user_config)
end

---Validate configuration
---@param cfg table
---@return boolean valid
---@return string|nil error
function M.validate(cfg)
  if type(cfg.timeout) ~= "number" or cfg.timeout < 1000 then
    return false, "timeout must be a number >= 1000"
  end

  return true, nil
end

return M
