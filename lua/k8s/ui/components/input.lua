--- input.lua - 入力ダイアログ（NuiInput）のヘルパー

local M = {}

---Validate port number input
---@param value string Input value
---@return boolean valid Is valid
---@return string|nil error Error message if invalid
function M.validate_port(value)
  local num = tonumber(value)
  if not num then
    return false, "Port must be a number"
  end
  if num < 1 or num > 65535 then
    return false, "Port must be between 1 and 65535"
  end
  return true, nil
end

---Validate replicas input
---@param value string Input value
---@return boolean valid Is valid
---@return string|nil error Error message if invalid
function M.validate_replicas(value)
  local num = tonumber(value)
  if not num then
    return false, "Replicas must be a number"
  end
  if num < 0 then
    return false, "Replicas must be 0 or greater"
  end
  return true, nil
end

return M
