--- help.lua - ヘルプ表示View

local M = {}

-- Keymap definitions for each view (matches view_allowed_actions in init.lua)
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
    { key = "<C-h>", action = "Back" },
  },
  describe = {
    { key = "l", action = "Logs" },
    { key = "e", action = "Exec" },
    { key = "D", action = "Delete" },
    { key = "?", action = "Help" },
    { key = "q", action = "Quit" },
    { key = "<C-h>", action = "Back" },
  },
  port_forward_list = {
    { key = "D", action = "Stop" },
    { key = "?", action = "Help" },
    { key = "q", action = "Quit" },
    { key = "<C-h>", action = "Back" },
  },
}

---Get keymaps for a specific view
---@param view_name string View name
---@return table[] keymaps Array of {key, action} pairs
function M.get_keymaps_for_view(view_name)
  return view_keymaps[view_name] or {}
end

---Format keymaps into display lines with aligned columns
---@param keymaps table[] Array of {key, action} pairs
---@param items_per_line number Number of items per line
---@return string[] lines Formatted lines
function M.format_keymap_lines(keymaps, items_per_line)
  if #keymaps == 0 then
    return {}
  end

  -- Calculate max widths for key and action
  local max_key_width = 0
  local max_action_width = 0
  for _, km in ipairs(keymaps) do
    max_key_width = math.max(max_key_width, #km.key)
    max_action_width = math.max(max_action_width, #km.action)
  end

  -- Format each keymap with fixed width
  local format_str = "%-" .. max_key_width .. "s %-" .. max_action_width .. "s"

  local lines = {}
  local current_line = {}

  for i, km in ipairs(keymaps) do
    local formatted = string.format(format_str, km.key, km.action)
    table.insert(current_line, formatted)

    if #current_line >= items_per_line or i == #keymaps then
      table.insert(lines, table.concat(current_line, "  "))
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

---Create help content from keymap definitions
---@param keymaps table Keymap definitions table
---@return string[] lines Help content lines
function M.create_help_content(keymaps)
  local lines = {}
  table.insert(lines, M.get_help_title())
  table.insert(lines, "")

  -- Convert keymaps table to array format for format_keymap_lines
  local keymap_array = {}
  for action, def in pairs(keymaps) do
    if type(def) == "table" and def.key then
      table.insert(keymap_array, { key = def.key, action = def.desc or action })
    end
  end

  -- Sort by key for consistent display
  table.sort(keymap_array, function(a, b)
    return a.key < b.key
  end)

  -- Format keymaps (4 items per line)
  local keymap_lines = M.format_keymap_lines(keymap_array, 4)
  for _, line in ipairs(keymap_lines) do
    table.insert(lines, line)
  end

  return lines
end

return M
