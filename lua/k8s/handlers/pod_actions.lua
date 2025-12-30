--- pod_actions.lua - Podアクション（logs, exec, port_forward）

local M = {}

local DEFAULT_SHELL = 'sh -c "[ -e /bin/bash ] && exec bash || exec sh"'

---Create logs action config
---@param pod table
---@param container string
---@param opts? { follow?: boolean, previous?: boolean, timestamps?: boolean }
---@return table action
function M.create_logs_action(pod, container, opts)
  opts = opts or {}
  return {
    type = "logs",
    pod_name = pod.name,
    namespace = pod.namespace,
    container = container,
    follow = opts.follow or false,
    previous = opts.previous or false,
    timestamps = opts.timestamps or false,
  }
end

---Create exec action config
---@param pod table
---@param container string
---@param opts? { command?: string }
---@return table action
function M.create_exec_action(pod, container, opts)
  opts = opts or {}
  return {
    type = "exec",
    pod_name = pod.name,
    namespace = pod.namespace,
    container = container,
    command = opts.command or DEFAULT_SHELL,
  }
end

---Create port forward action config
---@param pod table
---@param local_port number
---@param remote_port number
---@return table action
function M.create_port_forward_action(pod, local_port, remote_port)
  return {
    type = "port_forward",
    pod_name = pod.name,
    namespace = pod.namespace,
    local_port = local_port,
    remote_port = remote_port,
  }
end

---Validate if action can be performed on resource
---@param kind string
---@return boolean
function M.validate_pod_action(kind)
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

---Format tab name for terminal
---@param action_type "logs"|"exec"
---@param pod_name string
---@param container string
---@return string
function M.format_tab_name(action_type, pod_name, container)
  local prefix = action_type == "logs" and "[Logs]" or "[Exec]"
  return string.format("%s %s/%s", prefix, pod_name, container)
end

return M
