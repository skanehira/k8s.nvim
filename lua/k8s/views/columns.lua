--- columns.lua - リソースタイプごとのカラム定義
--- registry から取得

local registry = require("k8s.resources.registry")

local M = {}

---Get columns for a resource kind
---@param kind K8sResourceKind Resource kind
---@return Column[]
function M.get_columns(kind)
  return registry.get_columns(kind)
end

---Extract row data from resource
---@param resource table Resource with kind, name, namespace, status, age, raw
---@return table row Row data with keys matching column definitions
function M.extract_row(resource)
  return registry.extract_row(resource)
end

---Get the key of the column used for status highlighting
---@param kind K8sResourceKind Resource kind
---@return string key Column key for status
function M.get_status_column_key(kind)
  return registry.get_status_column_key(kind)
end

return M
