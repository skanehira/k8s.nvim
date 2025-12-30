--- notify.lua - 通知ヘルパー

local M = {}

---Format port forward message
---@param pod_name string
---@param local_port number
---@param remote_port number
---@param action "start"|"stop"
---@return string
function M.format_port_forward_message(pod_name, local_port, remote_port, action)
  if action == "start" then
    return string.format("Port forward started: localhost:%d -> %s:%d", local_port, pod_name, remote_port)
  else
    return string.format("Port forward stopped: localhost:%d -> %s:%d", local_port, pod_name, remote_port)
  end
end

---Format context switch message
---@param context string
---@return string
function M.format_context_switch_message(context)
  return string.format("Switched to context: %s", context)
end

---Format namespace switch message
---@param namespace string
---@return string
function M.format_namespace_switch_message(namespace)
  return string.format("Switched to namespace: %s", namespace)
end

return M
