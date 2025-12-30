--- filter_actions.lua - フィルターアクション

local M = {}

---Create filter action
---@param pattern string
---@return table action
function M.create_filter_action(pattern)
  return {
    type = "filter",
    pattern = pattern,
  }
end

---Create clear filter action
---@return table action
function M.create_clear_filter_action()
  return {
    type = "clear_filter",
  }
end

---Apply filter to resources
---@param resources table[]
---@param pattern string
---@return table[]
function M.apply_filter(resources, pattern)
  if not pattern or pattern == "" then
    return resources
  end

  local lower_pattern = pattern:lower()
  local filtered = {}

  for _, resource in ipairs(resources) do
    local name = (resource.name or ""):lower()
    local namespace = (resource.namespace or ""):lower()

    if name:find(lower_pattern, 1, true) or namespace:find(lower_pattern, 1, true) then
      table.insert(filtered, resource)
    end
  end

  return filtered
end

---Check if filter is active
---@param pattern string|nil
---@return boolean
function M.is_filter_active(pattern)
  return pattern ~= nil and pattern ~= ""
end

---Format filter prompt
---@return string
function M.format_filter_prompt()
  return "Filter: "
end

---Validate filter pattern
---@param pattern string
---@return boolean
function M.validate_filter_pattern(pattern)
  -- All patterns are valid, including empty
  return type(pattern) == "string"
end

return M
