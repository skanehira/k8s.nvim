--- navigation.lua - ナビゲーション（select, back, quit）

local M = {}

---Create select action
---@param resource table
---@return table action
function M.create_select_action(resource)
  return {
    type = "select",
    resource = resource,
  }
end

---Create back action
---@return table action
function M.create_back_action()
  return {
    type = "back",
  }
end

---Create quit action
---@return table action
function M.create_quit_action()
  return {
    type = "quit",
  }
end

---Check if can go back
---@param stack table[]
---@return boolean
function M.can_go_back(stack)
  return #stack > 1
end

---Get resource at cursor position
---@param resources table[]
---@param position number
---@return table|nil
function M.get_cursor_resource(resources, position)
  if position < 1 or position > #resources then
    return nil
  end
  return resources[position]
end

---Calculate next cursor position after action
---@param total number
---@param current number
---@param action_type string
---@return number
function M.calculate_next_cursor(total, current, action_type)
  if total <= 0 then
    return 1
  end

  if action_type == "delete" then
    if current > total then
      return total
    end
    return current
  end

  return math.min(current, total)
end

return M
