--- keymaps.lua - View type ごとのキーマップ定義

local M = {}

local resource_mod = require("k8s.handlers.resource")

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
}

-- Actions allowed for each view type
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
local footer_keymaps_def = {
  list = {
    { key = "d", action = "describe", desc = "Describe" },
    { key = "l", action = "logs", desc = "Logs" },
    { key = "D", action = "delete", desc = "Delete" },
    { key = "/", action = "filter", desc = "Filter" },
    { key = "r", action = "refresh", desc = "Refresh" },
    { key = "?", action = "help", desc = "Help" },
    { key = "q", action = "quit", desc = "Hide" },
  },
  describe = {
    { key = "<C-h>", action = "back", desc = "Back" },
    { key = "?", action = "help", desc = "Help" },
    { key = "q", action = "quit", desc = "Hide" },
  },
  port_forward_list = {
    { key = "D", action = "stop", desc = "Stop" },
    { key = "<C-h>", action = "back", desc = "Back" },
    { key = "q", action = "quit", desc = "Hide" },
  },
  help = {
    { key = "<C-h>", action = "back", desc = "Back" },
    { key = "q", action = "quit", desc = "Hide" },
  },
}

-- All keymaps for list view (used for keymap setup and help)
local list_keymaps = {
  { key = "<CR>", action = "select", desc = "Select" },
  { key = "d", action = "describe", desc = "Describe" },
  { key = "l", action = "logs", desc = "Logs" },
  { key = "P", action = "logs_previous", desc = "PrevLogs" },
  { key = "e", action = "exec", desc = "Exec" },
  { key = "p", action = "port_forward", desc = "PortFwd" },
  { key = "F", action = "port_forward_list", desc = "PortFwdList" },
  { key = "D", action = "delete", desc = "Delete" },
  { key = "s", action = "scale", desc = "Scale" },
  { key = "X", action = "restart", desc = "Restart" },
  { key = "r", action = "refresh", desc = "Refresh" },
  { key = "/", action = "filter", desc = "Filter" },
  { key = "R", action = "resource_menu", desc = "Resources" },
  { key = "C", action = "context_menu", desc = "Context" },
  { key = "N", action = "namespace_menu", desc = "Namespace" },
  { key = "?", action = "help", desc = "Help" },
  { key = "q", action = "quit", desc = "Hide" },
  { key = "<C-c>", action = "close", desc = "Close" },
  { key = "<C-h>", action = "back", desc = "Back" },
}

-- Keymaps for describe view
local describe_keymaps = {
  { key = "S", action = "toggle_secret", desc = "ToggleSecret" },
  { key = "?", action = "help", desc = "Help" },
  { key = "q", action = "quit", desc = "Hide" },
  { key = "<C-c>", action = "close", desc = "Close" },
  { key = "<C-h>", action = "back", desc = "Back" },
}

-- Port forward list view keymaps
local port_forward_list_keymaps = {
  { key = "D", action = "stop", desc = "Stop" },
  { key = "?", action = "help", desc = "Help" },
  { key = "q", action = "quit", desc = "Hide" },
  { key = "<C-c>", action = "close", desc = "Close" },
  { key = "<C-h>", action = "back", desc = "Back" },
}

-- Help view keymaps
local help_keymaps = {
  { key = "q", action = "quit", desc = "Hide" },
  { key = "<C-c>", action = "close", desc = "Close" },
  { key = "<C-h>", action = "back", desc = "Back" },
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
}

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
  -- Map view type prefix to resource kind
  local kind_map = {
    pod = "Pod",
    deployment = "Deployment",
    service = "Service",
    configmap = "ConfigMap",
    secret = "Secret",
    node = "Node",
    namespace = "Namespace",
  }

  -- Extract prefix (e.g., "pod" from "pod_list")
  local prefix = view_type:match("^(%w+)_")
  if prefix then
    return kind_map[prefix]
  end
  return nil
end

---Check if an action is allowed for a specific resource kind
---@param action string Action name
---@param kind string|nil Resource kind
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

  local base_type = M.get_base_view_type(view_type)
  local allowed = view_allowed_actions[base_type]
  return allowed and allowed[action] == true
end

---Get keymaps for a view type
---@param view_type string View type (e.g., "pod_list", "pod_describe")
---@return KeymapDef[]
function M.get_keymaps(view_type)
  local base_type = M.get_base_view_type(view_type)

  if base_type == "port_forward_list" then
    return port_forward_list_keymaps
  elseif base_type == "describe" then
    -- Only include toggle_secret for secret_describe
    if view_type == "secret_describe" then
      return describe_keymaps
    else
      -- Return describe keymaps without toggle_secret
      local filtered = {}
      for _, km in ipairs(describe_keymaps) do
        if km.action ~= "toggle_secret" then
          table.insert(filtered, km)
        end
      end
      return filtered
    end
  elseif base_type == "help" then
    return help_keymaps
  end

  -- For list views, filter keymaps based on resource capabilities
  local kind = M.get_kind_from_view_type(view_type)
  local filtered = {}
  for _, km in ipairs(list_keymaps) do
    if is_action_allowed_for_kind(km.action, kind) then
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
  local keymaps = footer_keymaps_def[base_type] or footer_keymaps_def.list

  -- For list views, filter based on resource capabilities
  local kind = nil
  if base_type == "list" then
    kind = M.get_kind_from_view_type(view_type)
  end

  local result = {}
  for _, km in ipairs(keymaps) do
    if is_action_allowed_for_kind(km.action, kind) then
      table.insert(result, { key = km.key, action = km.desc })
    end
  end
  return result
end

return M
