--- actions.lua - アクション定義とユーティリティ

local M = {}

local registry = require("k8s.resources.registry")

-- =============================================================================
-- Resource Actions
-- =============================================================================

---Format action result message
---@param action_type string
---@param kind K8sResourceKind
---@param name string
---@param success boolean
---@param error_msg? string
---@return string
function M.format_result(action_type, kind, name, success, error_msg)
  if success then
    local verb = action_type == "delete" and "deleted"
      or action_type == "scale" and "scaled"
      or action_type == "restart" and "restarted"
      or action_type
    return string.format("%s '%s' %s successfully", kind, name, verb)
  else
    return string.format("Failed to %s %s '%s': %s", action_type, kind, name, error_msg or "unknown error")
  end
end

-- =============================================================================
-- Pod Actions
-- =============================================================================

---Validate if resource supports pod actions (logs, exec)
---@param kind K8sResourceKind
---@return boolean
function M.is_pod(kind)
  return kind == "Pod"
end

---Check if container selection is needed
---@param pod table
---@return boolean
function M.needs_container_selection(pod)
  local containers = pod.raw and pod.raw.spec and pod.raw.spec.containers
  if not containers then
    return false
  end
  return #containers > 1
end

---Get default container name
---@param pod table
---@return string|nil
function M.get_default_container(pod)
  local containers = pod.raw and pod.raw.spec and pod.raw.spec.containers
  if not containers or #containers == 0 then
    return nil
  end
  return containers[1].name
end

---Get all container names
---@param pod table
---@return string[]
function M.get_containers(pod)
  local containers = pod.raw and pod.raw.spec and pod.raw.spec.containers
  if not containers then
    return {}
  end

  local names = {}
  for _, container in ipairs(containers) do
    table.insert(names, container.name)
  end
  return names
end

---Get ports from a resource for port forwarding
---Supports Pod, Deployment, and Service
---@param resource table
---@return table[] Array of { name: string, port: number, container: string, protocol: string }
function M.get_container_ports(resource)
  local kind = resource.kind
  local raw = resource.raw

  if not raw then
    return {}
  end

  local ports = {}

  if kind == "Pod" then
    -- Pod: Get container ports directly
    local containers = raw.spec and raw.spec.containers
    if containers then
      for _, container in ipairs(containers) do
        if container.ports then
          for _, port in ipairs(container.ports) do
            table.insert(ports, {
              name = port.name or "",
              port = port.containerPort,
              container = container.name,
              protocol = port.protocol or "TCP",
            })
          end
        end
      end
    end
  elseif kind == "Deployment" then
    -- Deployment: Get container ports from pod template
    local containers = raw.spec and raw.spec.template and raw.spec.template.spec and raw.spec.template.spec.containers
    if containers then
      for _, container in ipairs(containers) do
        if container.ports then
          for _, port in ipairs(container.ports) do
            table.insert(ports, {
              name = port.name or "",
              port = port.containerPort,
              container = container.name,
              protocol = port.protocol or "TCP",
            })
          end
        end
      end
    end
  elseif kind == "Service" then
    -- Service: Get service ports
    local service_ports = raw.spec and raw.spec.ports
    if service_ports then
      for _, port in ipairs(service_ports) do
        table.insert(ports, {
          name = port.name or "",
          port = port.port,
          targetPort = port.targetPort,
          container = "",
          protocol = port.protocol or "TCP",
        })
      end
    end
  end

  return ports
end

---Format tab name for terminal
---@param action_type "logs"|"exec"|"logs-prev"|"debug"
---@param pod_name string
---@param container string
---@return string
function M.format_tab_name(action_type, pod_name, container)
  local prefix_map = {
    logs = "[Logs]",
    exec = "[Exec]",
    ["logs-prev"] = "[Logs-Prev]",
    debug = "[Debug]",
  }
  local prefix = prefix_map[action_type] or "[Unknown]"
  return string.format("%s %s:%s", prefix, pod_name, container)
end

-- =============================================================================
-- Menu Actions
-- =============================================================================

---Get resource menu items
---@return table[]
function M.get_resource_menu_items()
  return registry.get_menu_items()
end

---Get menu title
---@param menu_type "resource"|"context"|"namespace"|"container"
---@return string
function M.get_menu_title(menu_type)
  local titles = {
    resource = "Select Resource Type",
    context = "Select Context",
    namespace = "Select Namespace",
    container = "Select Container",
  }
  return titles[menu_type] or "Select"
end

return M
