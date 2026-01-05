--- keymaps.lua - View type ごとのキーマップ定義

local M = {}

---@class KeymapDef
---@field key string Key sequence
---@field action string Action name
---@field desc string Description for help

-- Actions that require a resource to be selected
local resource_required_actions = {
  select = true,
  describe = true,
  logs = true,
  logs_previous = true,
  exec = true,
  port_forward = true,
  delete = true,
  scale = true,
  restart = true,
  debug = true,
  show_events = true,
}

---Get keymaps config from state
---@return table
local function get_keymaps_config()
  local state = require("k8s.state")
  local config = state.get_config()
  if config and config.keymaps then
    return config.keymaps
  end
  -- Fallback to default config
  local config_mod = require("k8s.config")
  return config_mod.get_defaults().keymaps
end

---Get base view type from view_type string
---@param view_type string View type (e.g., "pod_list", "pod_describe")
---@return string base_type "list", "describe", "port_forward_list", or "help"
function M.get_base_view_type(view_type)
  if view_type == "port_forward_list" then
    return "port_forward_list"
  elseif view_type == "help" then
    return "help"
  elseif view_type:match("_describe$") then
    return "describe"
  elseif view_type:match("_list$") then
    return "list"
  end
  return "list"
end

---Get view-specific keymaps key from view_type
---Falls back to base type if specific view type is not defined
---@param view_type string View type (e.g., "pod_list", "secret_describe")
---@return string keymaps_key Key to use for keymaps lookup
local function get_keymaps_key(view_type)
  local keymaps_config = get_keymaps_config()

  -- Check if view-specific keymaps exist (e.g., pod_list, secret_describe)
  if keymaps_config[view_type] then
    return view_type
  end

  -- Fall back to base type (e.g., describe, port_forward_list, help)
  return M.get_base_view_type(view_type)
end

---Build keymap definitions from config
---@param view_type string View type (e.g., "pod_list", "secret_describe")
---@return KeymapDef[]
local function build_keymaps_from_config(view_type)
  local keymaps_config = get_keymaps_config()
  local global = keymaps_config.global or {}
  local keymaps_key = get_keymaps_key(view_type)
  local view_specific = keymaps_config[keymaps_key] or {}
  local base_type = M.get_base_view_type(view_type)

  local result = {}

  -- Add view-specific keymaps first
  for action, def in pairs(view_specific) do
    table.insert(result, {
      key = def.key,
      action = action,
      desc = def.desc,
    })
  end

  -- Add global keymaps
  for action, def in pairs(global) do
    -- Skip help key for help view
    if base_type == "help" and action == "help" then
      goto continue
    end
    table.insert(result, {
      key = def.key,
      action = action,
      desc = def.desc,
    })
    ::continue::
  end

  return result
end

---Get keymaps for a view type
---@param view_type string View type (e.g., "pod_list", "pod_describe")
---@return KeymapDef[]
function M.get_keymaps(view_type)
  return build_keymaps_from_config(view_type)
end

---Get action name for a key in a specific view type
---@param view_type string View type
---@param key string Key sequence
---@return string|nil action Action name or nil
function M.get_action_for_key(view_type, key)
  local keymaps = M.get_keymaps(view_type)
  for _, km in ipairs(keymaps) do
    if km.key == key then
      return km.action
    end
  end
  return nil
end

---Check if an action requires a resource to be selected
---@param action string Action name
---@return boolean
function M.requires_resource_selection(action)
  return resource_required_actions[action] == true
end

---Get key for an action in a view type
---@param view_type string View type
---@param action string Action name
---@return string|nil key Key sequence or nil
function M.get_key_for_action(view_type, action)
  local keymaps = M.get_keymaps(view_type)
  for _, km in ipairs(keymaps) do
    if km.action == action then
      return km.key
    end
  end
  return nil
end

return M
