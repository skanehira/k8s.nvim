--- api.lua - 統一API（ファサード）

local M = {}

-- Supported actions
local supported_actions = {
  "get_resources",
  "describe",
  "delete",
  "scale",
  "restart",
  "logs",
  "exec",
  "port_forward",
  "get_contexts",
  "use_context",
  "get_namespaces",
}

-- Required parameters per action
local required_params = {
  get_resources = { "kind" },
  describe = { "kind", "name" },
  delete = { "kind", "name" },
  scale = { "kind", "name", "replicas" },
  restart = { "kind", "name" },
  logs = { "pod_name", "container" },
  exec = { "pod_name", "container" },
  port_forward = { "pod_name", "local_port", "remote_port" },
  get_contexts = {},
  use_context = { "context" },
  get_namespaces = {},
}

-- Destructive actions
local destructive_actions = {
  delete = true,
  restart = true,
}

---Create API request
---@param action string
---@param params table
---@return table request
function M.create_request(action, params)
  return {
    action = action,
    params = params or {},
  }
end

---Validate API request
---@param request table
---@return boolean valid
---@return string|nil error
function M.validate_request(request)
  if not request.action then
    return false, "action is required"
  end

  local required = required_params[request.action]
  if not required then
    return false, "unknown action: " .. request.action
  end

  for _, param in ipairs(required) do
    if request.params[param] == nil then
      return false, string.format("missing required parameter: %s", param)
    end
  end

  return true, nil
end

---Get required parameters for action
---@param action string
---@return string[]
function M.get_required_params(action)
  return required_params[action] or {}
end

---Check if action is destructive
---@param action string
---@return boolean
function M.is_destructive_action(action)
  return destructive_actions[action] == true
end

---Get list of supported actions
---@return string[]
function M.get_supported_actions()
  return supported_actions
end

---Create API response
---@param ok boolean
---@param data any
---@param error_msg? string
---@return table response
function M.create_response(ok, data, error_msg)
  return {
    ok = ok,
    data = data,
    error = error_msg,
  }
end

return M
