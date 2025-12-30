--- list.lua - リソース一覧取得アクション

local M = {}

---@type KubectlPort|nil
local adapter = nil

---Setup with adapter (dependency injection)
---@param kubectl_adapter KubectlPort
function M.setup(kubectl_adapter)
  adapter = kubectl_adapter
end

---Fetch resources
---@param kind string
---@param namespace string|nil
---@param callback fun(result: K8sResult)
function M.fetch(kind, namespace, callback)
  assert(adapter, "list.setup() must be called before fetch()")
  adapter.get_resources(kind, namespace, callback)
end

---Filter resources by name or namespace
---@param resources table[]
---@param filter_text string
---@return table[]
function M.filter(resources, filter_text)
  if filter_text == "" then
    return resources
  end

  local pattern = filter_text:lower()
  local result = {}

  for _, resource in ipairs(resources) do
    local name_match = resource.name and resource.name:lower():find(pattern, 1, true)
    local ns_match = resource.namespace and resource.namespace:lower():find(pattern, 1, true)
    if name_match or ns_match then
      table.insert(result, resource)
    end
  end

  return result
end

---Sort resources by name (alphabetically, case-insensitive)
---@param resources table[]
---@return table[]
function M.sort(resources)
  local sorted = {}
  for i, r in ipairs(resources) do
    sorted[i] = r
  end

  table.sort(sorted, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return sorted
end

---Reset adapter (for testing)
function M._reset()
  adapter = nil
end

return M
