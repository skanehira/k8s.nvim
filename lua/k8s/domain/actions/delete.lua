--- delete.lua - リソース削除アクション

local M = {}

---@type KubectlPort|nil
local adapter = nil

---Setup with adapter (dependency injection)
---@param kubectl_adapter KubectlPort
function M.setup(kubectl_adapter)
  adapter = kubectl_adapter
end

---Delete a resource
---@param kind string
---@param name string
---@param namespace string|nil
---@param callback fun(result: K8sResult)
function M.execute(kind, name, namespace, callback)
  assert(adapter, "delete.setup() must be called before execute()")
  adapter.delete(kind, name, namespace, callback)
end

---Reset adapter (for testing)
function M._reset()
  adapter = nil
end

return M
