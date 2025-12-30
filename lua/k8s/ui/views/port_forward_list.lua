--- port_forward_list.lua - ポートフォワード一覧View

local M = {}

-- Default keymap definitions for port forward list view
local default_keymaps = {
  ["<Esc>"] = "back",
  ["D"] = "stop",
  ["q"] = "quit",
}

-- Column definitions for port forward list
local columns = {
  { header = "LOCAL", key = "local_port" },
  { header = "REMOTE", key = "remote_port" },
  { header = "RESOURCE", key = "resource" },
  { header = "STATUS", key = "status" },
}

---Get default keymap definitions
---@return table<string, string> keymaps Key to action mapping
function M.get_default_keymaps()
  return default_keymaps
end

---Get action name for a key
---@param key string Key press
---@return string|nil action Action name or nil
function M.get_action_for_key(key)
  return default_keymaps[key]
end

---Get column definitions for the table
---@return table[] columns Column definitions
function M.get_columns()
  return columns
end

---Format a connection for display
---@param conn table Connection from connections state
---@return table formatted Formatted connection row
function M.format_connection(conn)
  return {
    local_port = conn.local_port,
    remote_port = conn.remote_port,
    resource = conn.resource,
    status = "Running", -- Always running if in connections list
  }
end

---Get connection at cursor position
---@param connections table[] Connection list
---@param cursor_pos number Cursor position (1-based)
---@return table|nil connection Connection at cursor or nil
function M.get_connection_at_cursor(connections, cursor_pos)
  if cursor_pos < 1 or cursor_pos > #connections then
    return nil
  end
  return connections[cursor_pos]
end

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

return M
