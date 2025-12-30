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

---Mask secret data in describe output lines
---@param masked boolean Whether to mask
---@param lines string[] Lines from describe output
---@return string[] Masked lines
function M.mask_describe_output(masked, lines)
  if not masked then
    return lines
  end

  local result = {}
  local in_data_section = false

  for _, line in ipairs(lines) do
    -- Check for Data section header
    if line:match("^Data$") or line:match("^Data:$") then
      in_data_section = true
      table.insert(result, line)
    -- Check for next section (ends Data section) - starts with letter without indent
    elseif in_data_section and line:match("^[A-Z]") and not line:match("^%s") and not line:match("^=") then
      in_data_section = false
      table.insert(result, line)
    -- Skip separator lines like "===="
    elseif in_data_section and line:match("^=+$") then
      table.insert(result, line)
    -- Mask value lines in Data section (format: "key:  N bytes" without leading space)
    elseif in_data_section and line:match("^[%w%-_%.]+:%s+%d+%s+bytes") then
      -- Keep key, replace bytes info with mask
      local key = line:match("^([%w%-_%.]+:)")
      if key then
        table.insert(result, key .. "  " .. MASK_STRING)
      else
        table.insert(result, line)
      end
    else
      table.insert(result, line)
    end
  end

  return result
end

return M
