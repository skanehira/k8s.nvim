--- scope.lua - 現在のスコープ（Context/Namespace）とリソースキャッシュを管理

local M = {}

---@class ScopeState
---@field context string
---@field namespace string|nil
---@field resource_type string
---@field filter string
---@field resources table[]

---@type ScopeState
local state = {
  context = "",
  namespace = "default",
  resource_type = "Pod",
  filter = "",
  resources = {},
}

---Clear resource cache
local function clear_cache()
  state.resources = {}
end

---Get current context
---@return string
function M.get_context()
  return state.context
end

---Set current context (clears cache)
---@param context string
function M.set_context(context)
  if state.context ~= context then
    state.context = context
    clear_cache()
  end
end

---Get current namespace
---@return string|nil
function M.get_namespace()
  return state.namespace
end

---Set current namespace (clears cache)
---@param namespace string|nil
function M.set_namespace(namespace)
  if state.namespace ~= namespace then
    state.namespace = namespace
    clear_cache()
  end
end

---Get current resource type
---@return string
function M.get_resource_type()
  return state.resource_type
end

---Set current resource type (clears cache)
---@param resource_type string
function M.set_resource_type(resource_type)
  if state.resource_type ~= resource_type then
    state.resource_type = resource_type
    clear_cache()
  end
end

---Get current filter
---@return string
function M.get_filter()
  return state.filter
end

---Set current filter (does NOT clear cache)
---@param filter string
function M.set_filter(filter)
  state.filter = filter
end

---Get cached resources
---@return table[]
function M.get_resources()
  return state.resources
end

---Set cached resources
---@param resources table[]
function M.set_resources(resources)
  state.resources = resources
end

---Reset all state to defaults
function M.reset()
  state.context = ""
  state.namespace = "default"
  state.resource_type = "Pod"
  state.filter = ""
  state.resources = {}
end

return M
