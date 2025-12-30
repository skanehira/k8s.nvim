--- renderer.lua - nui.nvim依存の描画モジュール

local header_component = require("k8s.ui.components.header")
local table_component = require("k8s.ui.components.table")

local M = {}

-- Action name to display name mapping
local action_display_names = {
  select = "Select",
  describe = "Describe",
  logs = "Logs",
  logs_previous = "Prev Logs",
  exec = "Exec",
  port_forward = "PortFwd",
  port_forward_list = "PortFwdList",
  delete = "Delete",
  scale = "Scale",
  restart = "Restart",
  refresh = "Refresh",
  filter = "Filter",
  resource_menu = "Resources",
  toggle_secret = "Secret",
  context_menu = "Context",
  namespace_menu = "Namespace",
  help = "Help",
  quit = "Quit",
  back = "Back",
}

---@class LayoutConfig
---@field header_height number Header height in lines
---@field footer_height number Footer height in lines
---@field border string|nil Border style

---Create layout configuration with defaults
---@param opts? { header_height?: number, footer_height?: number, border?: string }
---@return LayoutConfig
function M.create_layout_config(opts)
  opts = opts or {}
  return {
    header_height = opts.header_height or 1,
    footer_height = opts.footer_height or 1,
    border = opts.border or "none",
  }
end

---@class PopupPosition
---@field row number Row position
---@field col number Column position
---@field width number Width
---@field height number Height

---@class PopupPositions
---@field header PopupPosition Header position
---@field content PopupPosition Content position
---@field footer PopupPosition Footer position

---Calculate popup positions for 3 windows
---@param opts { width: number, height: number, header_height?: number, footer_height?: number }
---@return PopupPositions
function M.calculate_popup_positions(opts)
  local header_height = opts.header_height or 1
  local footer_height = opts.footer_height or 1
  local content_height = opts.height - header_height - footer_height

  return {
    header = {
      row = 1,
      col = 0,
      width = opts.width,
      height = header_height,
    },
    content = {
      row = header_height + 1,
      col = 0,
      width = opts.width,
      height = content_height,
    },
    footer = {
      row = opts.height,
      col = 0,
      width = opts.width,
      height = footer_height,
    },
  }
end

---Build header line text
---@param opts table Header options (context, namespace, view, filter, loading)
---@return string line Formatted header line
function M.build_header_line(opts)
  return header_component.format({
    context = opts.context,
    namespace = opts.namespace == "" and "All" or opts.namespace,
    view = opts.view,
    filter = opts.filter,
    loading = opts.loading,
  })
end

---Build footer line text
---@param keymaps table[] Keymap hints with key and desc
---@return string line Formatted footer line
function M.build_footer_line(keymaps)
  if #keymaps == 0 then
    return ""
  end

  local hints = {}
  for _, km in ipairs(keymaps) do
    table.insert(hints, km.key .. " " .. km.desc)
  end

  return header_component.format_footer(hints)
end

---Build table lines for content area
---@param columns table[] Column definitions
---@param rows table[] Data rows
---@return string[] lines Table lines
function M.build_table_lines(columns, rows)
  local widths = table_component.calculate_column_widths(columns, rows)
  local lines = {}

  -- Header line
  table.insert(lines, table_component.format_header(columns, widths))

  -- Data rows
  for _, row in ipairs(rows) do
    table.insert(lines, table_component.format_row(columns, widths, row))
  end

  return lines
end

---Get highlights for a data row
---@param columns table[] Column definitions
---@param row table Data row
---@return table[] highlights Highlight info for the row
function M.get_line_highlights(columns, row)
  local highlights = {}

  for _, col in ipairs(columns) do
    local value = row[col.key]
    if value then
      local hl_group = table_component.get_status_highlight(tostring(value))
      if hl_group then
        table.insert(highlights, {
          col_key = col.key,
          hl_group = hl_group,
          value = value,
        })
      end
    end
  end

  return highlights
end

---@class RenderState
---@field header_bufnr number|nil Header buffer number
---@field content_bufnr number|nil Content buffer number
---@field footer_bufnr number|nil Footer buffer number
---@field header_winid number|nil Header window ID
---@field content_winid number|nil Content window ID
---@field footer_winid number|nil Footer window ID
---@field timer userdata|nil vim.uv timer handle
---@field mounted boolean Whether the UI is mounted

---Create initial render state
---@return RenderState
function M.create_render_state()
  return {
    header_bufnr = nil,
    content_bufnr = nil,
    footer_bufnr = nil,
    header_winid = nil,
    content_winid = nil,
    footer_winid = nil,
    timer = nil,
    mounted = false,
  }
end

---Check if buffer should be reused
---@param state RenderState Render state
---@param section "header"|"content"|"footer" Section name
---@return boolean
function M.should_reuse_buffer(state, section)
  local bufnr_key = section .. "_bufnr"
  local bufnr = state[bufnr_key]

  if bufnr == nil then
    return false
  end

  return vim.api.nvim_buf_is_valid(bufnr)
end

---Create keymap handler function
---@param action string Action name
---@param callbacks table<string, function> Action callbacks
---@return function|nil handler Handler function or nil
function M.create_keymap_handler(action, callbacks)
  local callback = callbacks[action]
  if not callback then
    return nil
  end

  return function(resource)
    callback(resource)
  end
end

---Format keymaps for footer display
---@param keymaps table<string, string> Key to action mapping
---@return table[] hints Formatted hints with key and desc
function M.format_keymap_hints(keymaps)
  local hints = {}

  for key, action in pairs(keymaps) do
    local display_name = action_display_names[action] or action
    table.insert(hints, {
      key = key,
      desc = display_name,
    })
  end

  -- Sort by key for consistent ordering
  table.sort(hints, function(a, b)
    return a.key < b.key
  end)

  return hints
end

---@class TimerConfig
---@field interval number Timer interval in milliseconds
---@field is_running boolean Whether timer is running

---Create timer configuration
---@param interval? number Timer interval in milliseconds (default 5000)
---@return TimerConfig
function M.create_timer_config(interval)
  return {
    interval = interval or 5000,
    is_running = false,
  }
end

return M
