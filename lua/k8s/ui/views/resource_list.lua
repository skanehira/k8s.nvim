--- resource_list.lua - リソース一覧View

local state = require("k8s.core.state")
local resource = require("k8s.core.resource")

local M = {}

-- Default keymap definitions (key -> action name)
local default_keymaps = {
  ["<CR>"] = "select",
  ["d"] = "describe",
  ["l"] = "logs",
  ["P"] = "logs_previous",
  ["e"] = "exec",
  ["p"] = "port_forward",
  ["F"] = "port_forward_list",
  ["D"] = "delete",
  ["s"] = "scale",
  ["X"] = "restart",
  ["r"] = "refresh",
  ["/"] = "filter",
  ["R"] = "resource_menu",
  ["S"] = "toggle_secret",
  ["C"] = "context_menu",
  ["N"] = "namespace_menu",
  ["?"] = "help",
  ["q"] = "quit",
  ["<C-h>"] = "back",
}

-- Actions that require a resource to be selected
local resource_required_actions = {
  select = true,
  describe = true,
  logs = true,
  logs_previous = true,
  exec = true,
  port_forward = true,
  delete = true,
  scale = true,
  restart = true,
}

---Prepare display data by filtering and sorting resources
---@param resources table[] Raw resources
---@param filter_text string Filter text
---@return table[] Filtered and sorted resources
function M.prepare_display_data(resources, filter_text)
  local filtered = state.filter_resources(resources, filter_text)
  return state.sort_resources(filtered)
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

---Check if an action can be performed on a resource kind
---@param kind string Resource kind
---@param action string Action name (exec, logs, scale, restart, port_forward)
---@return boolean
function M.can_perform_action(kind, action)
  local caps = resource.capabilities(kind)
  if caps[action] == nil then
    return false
  end
  return caps[action]
end

---Get resource at cursor position
---@param resources table[] Resource list
---@param cursor_pos number Cursor position (1-based)
---@return table|nil resource Resource at cursor or nil
function M.get_resource_at_cursor(resources, cursor_pos)
  if cursor_pos < 1 or cursor_pos > #resources then
    return nil
  end
  return resources[cursor_pos]
end

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

---Check if an action requires a resource to be selected
---@param action string Action name
---@return boolean
function M.requires_resource_selection(action)
  return resource_required_actions[action] == true
end

---@class RefreshState
---@field interval number Refresh interval in milliseconds
---@field is_loading boolean Whether refresh is in progress
---@field timer userdata|nil vim.uv timer handle
---@field last_refresh number|nil Last refresh timestamp (seconds)

---Create initial refresh state
---@param interval number Refresh interval in milliseconds
---@return RefreshState
function M.create_refresh_state(interval)
  return {
    interval = interval,
    is_loading = false,
    timer = nil,
    last_refresh = nil,
  }
end

---Check if auto refresh should trigger
---@param refresh_state RefreshState
---@param current_time number Current timestamp (seconds)
---@return boolean
function M.should_auto_refresh(refresh_state, current_time)
  -- Don't refresh while loading
  if refresh_state.is_loading then
    return false
  end

  -- First refresh or never refreshed
  if refresh_state.last_refresh == nil then
    return true
  end

  -- Check if interval has passed (convert ms to seconds)
  local interval_seconds = refresh_state.interval / 1000
  return (current_time - refresh_state.last_refresh) >= interval_seconds
end

---Mark refresh as started
---@param refresh_state RefreshState
function M.mark_refresh_start(refresh_state)
  refresh_state.is_loading = true
end

---Mark refresh as complete
---@param refresh_state RefreshState
---@param current_time number Current timestamp (seconds)
function M.mark_refresh_complete(refresh_state, current_time)
  refresh_state.is_loading = false
  refresh_state.last_refresh = current_time
end

-- =============================================================================
-- View Rendering
-- =============================================================================

---@class TableViewRenderOptions
---@field resources table[] Resources to render (domain objects)
---@field kind string Resource kind
---@field restore_cursor? number Cursor position to restore

---Render table view (table_header + content)
---@param win K8sWindow Window instance
---@param opts TableViewRenderOptions
function M.render(win, opts)
  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")
  local columns_module = require("k8s.ui.views.columns")
  local table_component = require("k8s.ui.components.table")

  -- Get columns for this kind
  local columns = columns_module.get_columns(opts.kind)

  -- Extract row data from resources
  local rows = {}
  for _, res in ipairs(opts.resources) do
    table.insert(rows, columns_module.extract_row(res))
  end

  -- Prepare table content
  local content = buffer.prepare_table_content(columns, rows)

  -- Render table header
  local table_header_bufnr = window.get_table_header_bufnr(win)
  if table_header_bufnr then
    window.set_lines(table_header_bufnr, { content.header_line })
  end

  -- Render table content
  local content_bufnr = window.get_content_bufnr(win)
  if content_bufnr then
    window.set_lines(content_bufnr, content.data_lines)

    -- Apply status highlights
    local status_key = columns_module.get_status_column_key(opts.kind)
    local status_col_idx = buffer.find_status_column_index(columns, status_key)

    if status_col_idx then
      local hl_range = buffer.get_highlight_range(content.widths, status_col_idx)

      for i, row in ipairs(rows) do
        local status = row[status_key]
        local hl_group = table_component.get_status_highlight(status)
        if hl_group then
          window.add_highlight(content_bufnr, hl_group, i - 1, hl_range.start_col, hl_range.end_col)
        end
      end
    end
  end

  -- Restore cursor if specified
  if opts.restore_cursor then
    local pos = M.calculate_cursor_position(opts.restore_cursor, #rows)
    window.set_cursor(win, pos, 0)
  elseif #rows > 0 then
    window.set_cursor(win, 1, 0)
  end

  return {
    widths = content.widths,
    row_count = #rows,
  }
end

return M
