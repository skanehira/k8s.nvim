--- resource.lua - リソースの機能定義

---@class ResourceCapabilities
---@field exec boolean
---@field logs boolean
---@field scale boolean
---@field restart boolean
---@field port_forward boolean
---@field delete boolean

local M = {}

---@type table<string, ResourceCapabilities>
local capabilities_map = {
  Pod = {
    exec = true,
    logs = true,
    scale = false,
    restart = false,
    port_forward = true,
    delete = true,
  },
  Deployment = {
    exec = false,
    logs = false,
    scale = true,
    restart = true,
    port_forward = true,
    delete = true,
  },
  Service = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = true,
    delete = true,
  },
  ConfigMap = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
  },
  Secret = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
  },
  Node = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = false,
  },
  Namespace = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
  },
}

local default_capabilities = {
  exec = false,
  logs = false,
  scale = false,
  restart = false,
  port_forward = false,
  delete = false,
}

---Get capabilities for a resource kind
---@param kind string
---@return ResourceCapabilities
function M.capabilities(kind)
  return capabilities_map[kind] or default_capabilities
end

---Check if a resource kind can perform an action
---@param kind string
---@param action string
---@return boolean
function M.can_perform(kind, action)
  local caps = M.capabilities(kind)
  return caps[action] == true
end

return M
