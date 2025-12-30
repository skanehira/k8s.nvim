--- notify.lua - 通知ヘルパー

local M = {}

-- Destructive actions
local destructive_actions = {
  delete = true,
  restart = true,
}

---Create notification
---@param message string
---@param level? "info"|"warn"|"error"
---@return table notification
function M.create_notification(message, level)
  return {
    message = message,
    level = level or "info",
  }
end

---Format action message
---@param action string
---@param kind string
---@param name string
---@param success boolean
---@param error_msg? string
---@return string
function M.format_action_message(action, kind, name, success, error_msg)
  local past_tense = {
    delete = "deleted",
    scale = "scaled",
    restart = "restarted",
  }

  local verb = past_tense[action] or action

  if success then
    return string.format("%s '%s' %s successfully", kind, name, verb)
  else
    return string.format("Failed to %s %s '%s': %s", action, kind, name, error_msg or "unknown error")
  end
end

---Get notification level for action
---@param action string
---@param success boolean
---@return "info"|"warn"|"error"
function M.get_level_for_action(action, success)
  if not success then
    return "error"
  end

  if destructive_actions[action] then
    return "warn"
  end

  return "info"
end

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
