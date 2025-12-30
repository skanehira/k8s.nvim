---@class Resource
---@field kind string
---@field name string
---@field namespace string
---@field status string
---@field age string
---@field raw table

---@class ResourceCapabilities
---@field exec boolean
---@field logs boolean
---@field scale boolean
---@field restart boolean
---@field port_forward boolean

local M = {}

---@type table<string, string>
local kind_to_api = {
  Pod = "pods",
  Deployment = "deployments",
  Service = "services",
  ConfigMap = "configmaps",
  Secret = "secrets",
  Node = "nodes",
  Namespace = "namespaces",
}

---@type table<string, ResourceCapabilities>
local capabilities_map = {
  Pod = {
    exec = true,
    logs = true,
    scale = false,
    restart = false,
    port_forward = true,
  },
  Deployment = {
    exec = false,
    logs = false,
    scale = true,
    restart = true,
    port_forward = false,
  },
  Service = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = true,
  },
  ConfigMap = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
  },
  Secret = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
  },
  Node = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
  },
  Namespace = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
  },
}

local default_capabilities = {
  exec = false,
  logs = false,
  scale = false,
  restart = false,
  port_forward = false,
}

---Create a new resource
---@param opts table
---@return Resource
function M.new(opts)
  return {
    kind = opts.kind,
    name = opts.name,
    namespace = opts.namespace,
    status = opts.status,
    age = opts.age,
    raw = opts.raw,
  }
end

---Get capabilities for a resource kind
---@param kind string
---@return ResourceCapabilities
function M.capabilities(kind)
  return capabilities_map[kind] or default_capabilities
end

---Get list of supported resource kinds
---@return string[]
function M.get_kind_list()
  local kinds = {}
  for kind, _ in pairs(kind_to_api) do
    table.insert(kinds, kind)
  end
  table.sort(kinds)
  return kinds
end

---Get API name for a kind
---@param kind string
---@return string
function M.get_api_name(kind)
  return kind_to_api[kind] or kind:lower() .. "s"
end

return M
