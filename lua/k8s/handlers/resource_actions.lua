--- resource_actions.lua - リソースアクション（describe, delete, scale, restart）

local M = {}

-- Deletable resource kinds
local deletable_kinds = {
  Pod = true,
  Deployment = true,
  Service = true,
  ConfigMap = true,
  Secret = true,
}

-- Scalable resource kinds
local scalable_kinds = {
  Deployment = true,
}

-- Restartable resource kinds
local restartable_kinds = {
  Deployment = true,
}

---Create describe action config
---@param resource { kind: string, name: string, namespace: string }
---@return table action
function M.create_describe_action(resource)
  return {
    type = "describe",
    resource = resource,
  }
end

---Create delete action config
---@param resource { kind: string, name: string, namespace: string }
---@return table action
function M.create_delete_action(resource)
  return {
    type = "delete",
    resource = resource,
    requires_confirm = true,
    confirm_message = string.format("Delete %s '%s'?", resource.kind, resource.name),
  }
end

---Create scale action config
---@param resource { kind: string, name: string, namespace: string }
---@param replicas number
---@param current_replicas? number
---@return table action
function M.create_scale_action(resource, replicas, current_replicas)
  return {
    type = "scale",
    resource = resource,
    replicas = replicas,
    current_replicas = current_replicas,
  }
end

---Create restart action config
---@param resource { kind: string, name: string, namespace: string }
---@return table action
function M.create_restart_action(resource)
  return {
    type = "restart",
    resource = resource,
    requires_confirm = true,
    confirm_message = string.format("Restart %s '%s'?", resource.kind, resource.name),
  }
end

---Validate if resource can be deleted
---@param kind string
---@return boolean
function M.validate_delete_target(kind)
  return deletable_kinds[kind] == true
end

---Validate if resource can be scaled
---@param kind string
---@return boolean
function M.validate_scale_target(kind)
  return scalable_kinds[kind] == true
end

---Validate if resource can be restarted
---@param kind string
---@return boolean
function M.validate_restart_target(kind)
  return restartable_kinds[kind] == true
end

---Format action result message
---@param action_type string
---@param kind string
---@param name string
---@param success boolean
---@param error_msg? string
---@return string
function M.format_action_result(action_type, kind, name, success, error_msg)
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

---Get notification level for action
---@param action_type string
---@return "info"|"warn"|"error"
function M.get_action_notification_level(action_type)
  if action_type == "delete" or action_type == "restart" then
    return "warn"
  end
  return "info"
end

return M
