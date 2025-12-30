--- utils.lua - View共通ユーティリティ

local M = {}

---Calculate cursor position within bounds
---@param current_pos number Current cursor position
---@param item_count number Number of items
---@return number position Clamped cursor position (1-based)
function M.calculate_cursor_position(current_pos, item_count)
  if item_count == 0 then
    return 1
  end

  if current_pos < 1 then
    return 1
  end

  if current_pos > item_count then
    return item_count
  end

  return current_pos
end

---Get item at cursor position from a list
---@param items table[] Item list
---@param cursor_pos number Cursor position (1-based)
---@return table|nil item Item at cursor or nil
function M.get_item_at_cursor(items, cursor_pos)
  if cursor_pos < 1 or cursor_pos > #items then
    return nil
  end
  return items[cursor_pos]
end

return M
