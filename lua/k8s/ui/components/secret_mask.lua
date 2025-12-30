--- secret_mask.lua - Secretマスク表示コンポーネント

local M = {}

local MASK_STRING = "********"

---@class SecretMaskState
---@field masked boolean Whether secret values are masked

---Create initial mask state
---@return SecretMaskState
function M.create_state()
  return {
    masked = true,
  }
end

---Toggle mask state
---@param state SecretMaskState
function M.toggle(state)
  state.masked = not state.masked
end

---Check if currently masked
---@param state SecretMaskState
---@return boolean
function M.is_masked(state)
  return state.masked
end

---Mask a single value
---@param state SecretMaskState
---@param value string|nil Value to mask
---@return string
function M.mask_value(state, value)
  if value == nil then
    return ""
  end

  if state.masked then
    return MASK_STRING
  end

  return value
end

---Mask all values in secret data table
---@param state SecretMaskState
---@param data table|nil Secret data table
---@return table
function M.mask_secret_data(state, data)
  if data == nil then
    return {}
  end

  local result = {}
  for key, value in pairs(data) do
    result[key] = M.mask_value(state, value)
  end

  return result
end

---Get status text for display
---@param state SecretMaskState
---@return string
function M.get_status_text(state)
  if state.masked then
    return "Hidden"
  end
  return "Visible"
end

return M
