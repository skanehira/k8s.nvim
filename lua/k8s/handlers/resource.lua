--- resource.lua - リソースの機能定義
--- registry から capabilities を取得

local registry = require("k8s.resources.registry")

---@alias K8sResourceKind string

local M = {}

---Get capabilities for a resource kind
---@param kind K8sResourceKind
---@return ResourceCapabilities
function M.capabilities(kind)
  return registry.capabilities(kind)
end

---Check if a resource kind can perform an action
---@param kind K8sResourceKind
---@param action string
---@return boolean
function M.can_perform(kind, action)
  return registry.can_perform(kind, action)
end

return M
