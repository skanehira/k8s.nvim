--- help.lua - ヘルプ表示View

local M = {}

-- Keymap definitions for each view
local view_keymaps = {
  resource_list = {
    { key = "<CR>", action = "Select" },
    { key = "d", action = "Describe" },
    { key = "l", action = "Logs" },
    { key = "e", action = "Exec" },
    { key = "p", action = "PortFwd" },
    { key = "D", action = "Delete" },
    { key = "s", action = "Scale" },
    { key = "X", action = "Restart" },
    { key = "r", action = "Refresh" },
    { key = "/", action = "Filter" },
    { key = "R", action = "Resources" },
    { key = "C", action = "Context" },
    { key = "N", action = "Namespace" },
    { key = "S", action = "Secret" },
    { key = "F", action = "PortFwdList" },
    { key = "P", action = "PrevLogs" },
    { key = "?", action = "Help" },
    { key = "q", action = "Quit" },
    { key = "<Esc>", action = "Back" },
  },
  describe = {
    { key = "<Esc>", action = "Back" },
    { key = "l", action = "Logs" },
    { key = "e", action = "Exec" },
    { key = "D", action = "Delete" },
    { key = "q", action = "Quit" },
  },
  port_forward_list = {
    { key = "<Esc>", action = "Back" },
    { key = "D", action = "Stop" },
    { key = "q", action = "Quit" },
  },
}

---Get keymaps for a specific view
---@param view_name string View name
---@return table[] keymaps Array of {key, action} pairs
function M.get_keymaps_for_view(view_name)
  return view_keymaps[view_name] or {}
end

---Format keymaps into display lines
---@param keymaps table[] Array of {key, action} pairs
---@param items_per_line number Number of items per line
---@return string[] lines Formatted lines
function M.format_keymap_lines(keymaps, items_per_line)
  local lines = {}
  local current_line = {}

  for i, km in ipairs(keymaps) do
    table.insert(current_line, km.key .. " " .. km.action)

    if #current_line >= items_per_line or i == #keymaps then
      table.insert(lines, table.concat(current_line, "    "))
      current_line = {}
    end
  end

  return lines
end

---Get help title
---@return string title
function M.get_help_title()
  return "Keymaps:"
end

---Get close hint message
---@return string hint
function M.get_close_hint()
  return "Press any key to close help..."
end

return M
