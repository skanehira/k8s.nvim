--- describe.lua - describe View

local resource = require("k8s.domain.resources.resource")

local M = {}

-- Default keymap definitions for describe view
local default_keymaps = {
  ["<C-h>"] = "back",
  ["l"] = "logs",
  ["e"] = "exec",
  ["D"] = "delete",
  ["q"] = "quit",
}

---Get default keymap definitions
---@return table<string, string> keymaps Key to action mapping
function M.get_default_keymaps()
  return default_keymaps
end

---Get action name for a key
---@param key string Key press
---@return string|nil action Action name or nil
function M.get_action_for_key(key)
  return default_keymaps[key]
end

---@class DescribeHeaderInfo
---@field kind string Resource kind
---@field name string Resource name
---@field namespace string Namespace

---Format header information for describe view
---@param kind string Resource kind
---@param name string Resource name
---@param namespace string Namespace
---@return DescribeHeaderInfo
function M.format_header_info(kind, name, namespace)
  return {
    kind = kind,
    name = name,
    namespace = namespace,
  }
end

---Get filetype for describe buffer
---@return string filetype
function M.get_filetype()
  return "yaml"
end

---Check if an action can be performed on this resource
---@param kind string Resource kind
---@param action string Action name
---@return boolean
function M.can_perform_action(kind, action)
  -- delete is always available
  if action == "delete" then
    return true
  end

  -- Check resource capabilities for other actions
  local caps = resource.capabilities(kind)
  if caps[action] == nil then
    return false
  end
  return caps[action]
end

return M
