--- keymaps.lua - View type ごとのキーマップ定義

local M = {}

local resource_mod = require("k8s.handlers.resource")
local registry = require("k8s.resources.registry")

---@class KeymapDef
---@field key string Key sequence
---@field action string Action name
---@field desc string Description for help

-- Actions that require resource capability check
-- Maps action name to capability name in resource.lua
local resource_capability_actions = {
  logs = "logs",
  logs_previous = "logs",
  exec = "exec",
  scale = "scale",
  restart = "restart",
  port_forward = "port_forward",
  delete = "delete",
  filter = "filter",
  refresh = "refresh",
}

-- Actions allowed for each view type (base)
local view_allowed_actions = {
  list = {
    describe = true,
    select = true,
    delete = true,
    logs = true,
    logs_previous = true,
    exec = true,
    scale = true,
    restart = true,
    port_forward = true,
    port_forward_list = true,
    filter = true,
    refresh = true,
    resource_menu = true,
    context_menu = true,
    namespace_menu = true,
    show_events = true,
    help = true,
    quit = true,
    close = true,
    back = true,
  },
  describe = {
    back = true,
    quit = true,
    close = true,
    help = true,
    -- Note: toggle_secret is handled specially in is_action_allowed()
  },
  port_forward_list = {
    back = true,
    stop = true,
    quit = true,
    close = true,
    help = true,
  },
  help = {
    back = true,
    quit = true,
    close = true,
  },
}

-- Footer keymaps for each view type (displayed in footer)
local footer_actions = {
  list = { "describe", "logs", "show_events", "delete", "filter", "refresh", "help", "quit" },
  describe = { "back", "help", "quit" },
  port_forward_list = { "stop", "back", "quit" },
  help = { "back", "quit" },
}

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

---Get resource kind from view_type string
---@param view_type string View type (e.g., "pod_list", "deployment_describe")
---@return string|nil kind Resource kind (e.g., "Pod", "Deployment") or nil
function M.get_kind_from_view_type(view_type)
  -- Extract prefix (e.g., "pod" from "pod_list")
  local prefix = view_type:match("^(%w+)_")
  if not prefix then
    return nil
  end

  -- Find matching kind from registry
  for kind in pairs(registry.resources) do
    if string.lower(kind) == prefix then
      return kind
    end
  end
  return nil
end

---Check if an action is allowed for a specific resource kind
---@param action string Action name
---@param kind K8sResourceKind|nil Resource kind
---@return boolean
local function is_action_allowed_for_kind(action, kind)
  local capability = resource_capability_actions[action]
  if not capability then
    -- Action doesn't require capability check
    return true
  end
  if not kind then
    -- No kind means we can't check, allow by default
    return true
  end
  return resource_mod.can_perform(kind, capability)
end

---Check if an action is allowed for a view type
---@param view_type string View type
---@param action string Action name
---@return boolean
function M.is_action_allowed(view_type, action)
  -- toggle_secret is only allowed for secret_describe
  if action == "toggle_secret" then
    return view_type == "secret_describe"
  end

  -- show_events is only allowed for pod_list
  if action == "show_events" then
    return view_type == "pod_list"
  end

  local base_type = M.get_base_view_type(view_type)
  local allowed = view_allowed_actions[base_type]
  return allowed and allowed[action] == true
end

---Build keymap definitions from config
---@param base_type string Base view type ("list", "describe", etc.)
---@param kind K8sResourceKind|nil Resource kind for capability filtering
---@return KeymapDef[]
local function build_keymaps_from_config(base_type, kind)
  local keymaps_config = get_keymaps_config()
  local global = keymaps_config.global or {}
  local view_specific = keymaps_config[base_type] or {}

  local result = {}

  -- Add view-specific keymaps first
  for action, def in pairs(view_specific) do
    if is_action_allowed_for_kind(action, kind) then
      table.insert(result, {
        key = def.key,
        action = action,
        desc = def.desc,
      })
    end
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
  local base_type = M.get_base_view_type(view_type)
  local kind = nil

  if base_type == "list" then
    kind = M.get_kind_from_view_type(view_type)
  end

  local keymaps = build_keymaps_from_config(base_type, kind)

  -- Filter keymaps based on view-specific action permissions
  local filtered = {}
  for _, km in ipairs(keymaps) do
    if M.is_action_allowed(view_type, km.action) then
      table.insert(filtered, km)
    end
  end

  return filtered
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

---Get footer keymaps for display
---@param view_type string View type
---@return { key: string, action: string }[]
function M.get_footer_keymaps(view_type)
  local base_type = M.get_base_view_type(view_type)
  local keymaps_config = get_keymaps_config()
  local global = keymaps_config.global or {}
  local view_specific = keymaps_config[base_type] or {}
  local actions = footer_actions[base_type] or footer_actions.list

  local kind = nil
  if base_type == "list" then
    kind = M.get_kind_from_view_type(view_type)
  end

  local result = {}
  for _, action in ipairs(actions) do
    -- Check if action is allowed for this view type
    if not M.is_action_allowed(view_type, action) then
      goto continue
    end

    -- Check capability for resource actions
    if not is_action_allowed_for_kind(action, kind) then
      goto continue
    end

    -- Get keymap definition
    local def = view_specific[action] or global[action]
    if def then
      table.insert(result, { key = def.key, action = def.desc })
    end
    ::continue::
  end

  return result
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
