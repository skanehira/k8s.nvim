--- menu_actions.lua - メニューアクション（resource, context, namespace選択）

local M = {}

-- Resource types available in menu
local resource_types = {
  { text = "Pods", value = "Pod" },
  { text = "Deployments", value = "Deployment" },
  { text = "Services", value = "Service" },
  { text = "ConfigMaps", value = "ConfigMap" },
  { text = "Secrets", value = "Secret" },
  { text = "Nodes", value = "Node" },
  { text = "Namespaces", value = "Namespace" },
}

---Create resource menu action
---@return table action
function M.create_resource_menu_action()
  return {
    type = "resource_menu",
  }
end

---Create context menu action
---@return table action
function M.create_context_menu_action()
  return {
    type = "context_menu",
  }
end

---Create namespace menu action
---@return table action
function M.create_namespace_menu_action()
  return {
    type = "namespace_menu",
  }
end

---Get resource menu items
---@return table[]
function M.get_resource_menu_items()
  return resource_types
end

---Create menu item
---@param text string
---@param value any
---@return table
function M.create_menu_item(text, value)
  return {
    text = text,
    value = value,
  }
end

---Get menu title
---@param menu_type "resource"|"context"|"namespace"
---@return string
function M.get_menu_title(menu_type)
  local titles = {
    resource = "Select Resource Type",
    context = "Select Context",
    namespace = "Select Namespace",
  }
  return titles[menu_type] or "Select"
end

---Create switch context action
---@param context string
---@return table action
function M.create_switch_context_action(context)
  return {
    type = "switch_context",
    context = context,
  }
end

---Create switch namespace action
---@param namespace string
---@return table action
function M.create_switch_namespace_action(namespace)
  return {
    type = "switch_namespace",
    namespace = namespace,
  }
end

---Create switch resource action
---@param kind string
---@return table action
function M.create_switch_resource_action(kind)
  return {
    type = "switch_resource",
    kind = kind,
  }
end

return M
