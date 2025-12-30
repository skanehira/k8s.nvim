--- view_stack.lua - ビュースタック管理

local M = {}

---Create empty view stack
---@return table[] stack
function M.create()
  return {}
end

---Get stack size
---@param stack table[]
---@return number
function M.size(stack)
  return #stack
end

---Push view onto stack (immutable)
---@param stack table[]
---@param view table
---@return table[] new_stack
function M.push(stack, view)
  local new_stack = {}
  for i, v in ipairs(stack) do
    new_stack[i] = v
  end
  table.insert(new_stack, view)
  return new_stack
end

---Pop view from stack (immutable)
---@param stack table[]
---@return table[] new_stack
---@return table|nil popped_view
function M.pop(stack)
  if #stack == 0 then
    return {}, nil
  end

  local new_stack = {}
  for i = 1, #stack - 1 do
    new_stack[i] = stack[i]
  end

  return new_stack, stack[#stack]
end

---Get current (top) view
---@param stack table[]
---@return table|nil
function M.current(stack)
  if #stack == 0 then
    return nil
  end
  return stack[#stack]
end

---Clear all views
---@param _ table[] stack (unused but kept for API consistency)
---@return table[] empty_stack
function M.clear(_)
  return {}
end

---Check if stack can be popped
---@param stack table[]
---@return boolean
function M.can_pop(stack)
  return #stack > 1
end

---Peek at view at specific index (1-based)
---@param stack table[]
---@param index number
---@return table|nil
function M.peek(stack, index)
  if index < 1 or index > #stack then
    return nil
  end
  return stack[index]
end

return M
