--- describe.lua - リソース詳細取得アクション

local M = {}

---@type KubectlPort|nil
local adapter = nil

---Setup with adapter (dependency injection)
---@param kubectl_adapter KubectlPort
function M.setup(kubectl_adapter)
  adapter = kubectl_adapter
end

---Fetch resource details
---@param kind string
---@param name string
---@param namespace string|nil
---@param callback fun(result: K8sResult)
function M.fetch(kind, name, namespace, callback)
  assert(adapter, "describe.setup() must be called before fetch()")
  adapter.describe(kind, name, namespace, callback)
end

---Reset adapter (for testing)
function M._reset()
  adapter = nil
end

return M
