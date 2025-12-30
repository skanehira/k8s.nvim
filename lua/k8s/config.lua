--- config.lua - 設定管理

local M = {}

-- Default keymaps
local default_keymaps = {
  describe = "d",
  delete = "D",
  logs = "l",
  exec = "e",
  scale = "s",
  restart = "X",
  port_forward = "F",
  filter = "/",
  refresh = "R",
  context_menu = "C",
  namespace_menu = "N",
  resource_menu = "S",
  port_forward_list = "P",
  help = "?",
  quit = "q",
  back = "<Esc>",
  select = "<CR>",
}

-- Default configuration
local defaults = {
  refresh_interval = 5000, -- 5 seconds
  timeout = 30000, -- 30 seconds
  default_namespace = "default",
  default_kind = "Pod",
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
  if type(cfg.refresh_interval) ~= "number" or cfg.refresh_interval < 500 then
    return false, "refresh_interval must be a number >= 500"
  end

  if type(cfg.timeout) ~= "number" or cfg.timeout < 1000 then
    return false, "timeout must be a number >= 1000"
  end

  return true, nil
end

---Get keymap for action
---@param cfg table
---@param action string
---@return string|nil
function M.get_keymap(cfg, action)
  return cfg.keymaps and cfg.keymaps[action]
end

---Get all keymaps as list
---@param cfg table
---@return table[]
function M.get_all_keymaps(cfg)
  local keymaps = {}
  for action, key in pairs(cfg.keymaps or {}) do
    table.insert(keymaps, {
      action = action,
      key = key,
    })
  end
  return keymaps
end

return M
