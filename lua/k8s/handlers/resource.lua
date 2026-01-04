--- resource.lua - リソースの機能定義

---@alias K8sResourceKind "Pod"|"Deployment"|"Service"|"ConfigMap"|"Secret"|"Node"|"Namespace"|"Application"|"StatefulSet"|"DaemonSet"|"Job"|"CronJob"|"Event"|"Ingress"|"ReplicaSet"

---@class ResourceCapabilities
---@field exec boolean
---@field logs boolean
---@field scale boolean
---@field restart boolean
---@field port_forward boolean
---@field delete boolean
---@field filter boolean
---@field refresh boolean

local M = {}

---@type table<K8sResourceKind, ResourceCapabilities>
local capabilities_map = {
  Pod = {
    exec = true,
    logs = true,
    scale = false,
    restart = false,
    port_forward = true,
    delete = true,
    filter = true,
    refresh = true,
  },
  Deployment = {
    exec = false,
    logs = false,
    scale = true,
    restart = true,
    port_forward = true,
    delete = true,
    filter = true,
    refresh = true,
  },
  Service = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = true,
    delete = true,
    filter = true,
    refresh = true,
  },
  ConfigMap = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  Secret = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  Node = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = false,
    filter = true,
    refresh = true,
  },
  Namespace = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  Application = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = false,
    filter = true,
    refresh = false,
  },
  StatefulSet = {
    exec = false,
    logs = false,
    scale = true,
    restart = true,
    port_forward = true,
    delete = true,
    filter = true,
    refresh = true,
  },
  DaemonSet = {
    exec = false,
    logs = false,
    scale = false,
    restart = true,
    port_forward = true,
    delete = true,
    filter = true,
    refresh = true,
  },
  Job = {
    exec = false,
    logs = true,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  CronJob = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  Event = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = false,
    filter = true,
    refresh = true,
  },
  Ingress = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  ReplicaSet = {
    exec = false,
    logs = false,
    scale = true,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
}

local default_capabilities = {
  exec = false,
  logs = false,
  scale = false,
  restart = false,
  port_forward = false,
  delete = false,
  filter = true,
  refresh = true,
}

---Get capabilities for a resource kind
---@param kind K8sResourceKind
---@return ResourceCapabilities
function M.capabilities(kind)
  return capabilities_map[kind] or default_capabilities
end

---Check if a resource kind can perform an action
---@param kind K8sResourceKind
---@param action string
---@return boolean
function M.can_perform(kind, action)
  local caps = M.capabilities(kind)
  return caps[action] == true
end

return M
