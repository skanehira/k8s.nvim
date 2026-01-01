---@class ResourceCapabilities
---@field exec boolean
---@field logs boolean
---@field scale boolean
---@field restart boolean
---@field port_forward boolean

local M = {}

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
    port_forward = true,
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

---Get capabilities for a resource kind
---@param kind string
---@return ResourceCapabilities
function M.capabilities(kind)
  return capabilities_map[kind] or default_capabilities
end

return M
