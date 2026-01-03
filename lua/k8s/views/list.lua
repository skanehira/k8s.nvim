--- list.lua - リスト表示ビュー
--- Lifecycle: on_mounted (Watcher開始), on_unmounted (Watcher停止), render (UI描画)

local M = {}

local columns = require("k8s.views.columns")
local buffer = require("k8s.ui.nui.buffer")
local table_component = require("k8s.ui.components.table")

-- =============================================================================
-- View Factory
-- =============================================================================

---Create a list view with lifecycle callbacks
---@param kind string Resource kind (e.g., "Pod", "Deployment")
---@param opts? { window?: table }
---@return ViewState
function M.create_view(kind, opts)
  opts = opts or {}
  local view_module = require("k8s.state.view")
  local view_type = view_module.get_list_type_from_kind(kind)

  -- Create view state with lifecycle callbacks
  local view_state = view_module.create_list_state(view_type, {
    window = opts.window,
    on_mounted = function(view)
      M._on_mounted(view, kind)
    end,
    on_unmounted = function(view)
      M._on_unmounted(view)
    end,
    render = function(view, win)
      M._render(view, win, kind)
    end,
  })

  return view_state
end

---Called when view is mounted (shown)
---@param _view ViewState (unused, but required for lifecycle interface)
---@param kind string
function M._on_mounted(_view, kind)
  local watcher = require("k8s.handlers.watcher")
  local state = require("k8s.state")

  -- Get current namespace from state (not from captured value)
  local namespace = state.get_namespace()

  -- Start watcher for this resource kind
  watcher.start(kind, namespace, {
    on_started = function()
      state.notify()
    end,
  })
end

---Called when view is unmounted (hidden)
---@param _view ViewState (unused, but required for lifecycle interface)
function M._on_unmounted(_view)
  local watcher = require("k8s.handlers.watcher")
  watcher.stop()
end

---Render the list view
---@param view ViewState
---@param win table Window reference
---@param kind string
function M._render(view, win, kind)
  local window = require("k8s.ui.nui.window")
  local state = require("k8s.state")
  local keymaps = require("k8s.views.keymaps")

  if not win or not window.is_mounted(win) then
    return
  end

  -- Show table header for list view
  window.show_table_header(win)

  -- Update header
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = state.get_namespace(),
      view = kind .. "s",
      filter = view.filter,
    })
    window.set_lines(header_bufnr, { header_content })
  end

  -- Get current cursor position before re-rendering
  local current_cursor = window.get_cursor(win)

  -- Render resources
  local filtered = M.filter_resources(view.resources or {}, view.filter)
  M.render(win, {
    resources = filtered,
    kind = kind,
    restore_cursor = current_cursor,
  })

  -- Update footer
  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local footer_keymaps = keymaps.get_footer_keymaps(view.type)
    local footer_content = buffer.create_footer_content(footer_keymaps)
    window.set_lines(footer_bufnr, { footer_content })
  end
end

-- =============================================================================
-- Utility Functions
-- =============================================================================

---Filter resources by name
---@param resources table[] List of resources
---@param filter string|nil Filter string
---@return table[] Filtered resources
function M.filter_resources(resources, filter)
  if not filter or filter == "" then
    return resources
  end

  local filtered = {}
  local pattern = filter:lower()
  for _, resource in ipairs(resources) do
    if resource.name and resource.name:lower():find(pattern, 1, true) then
      table.insert(filtered, resource)
    end
  end
  return filtered
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

---@class ListRenderResult
---@field widths number[] Column widths
---@field row_count number Number of rows rendered
---@field header_line string Header line content
---@field data_lines string[] Data line contents

---Prepare list view content for rendering
---@param resources table[] Resources to render
---@param kind string Resource kind (e.g., "Pod", "Deployment")
---@return ListRenderResult
function M.prepare_content(resources, kind)
  -- Get columns for this kind
  local cols = columns.get_columns(kind)

  -- Extract row data from resources
  local rows = {}
  for _, res in ipairs(resources) do
    table.insert(rows, columns.extract_row(res))
  end

  -- Prepare table content
  local content = buffer.prepare_table_content(cols, rows)

  return {
    widths = content.widths,
    row_count = #rows,
    header_line = content.header_line,
    data_lines = content.data_lines,
    columns = cols,
    rows = rows,
  }
end

---Get status highlights for rows
---@param kind string Resource kind
---@param rows table[] Row data
---@param widths number[] Column widths
---@return { row: number, start_col: number, end_col: number, hl_group: string }[]
function M.get_status_highlights(kind, rows, widths)
  local cols = columns.get_columns(kind)
  local status_key = columns.get_status_column_key(kind)
  local status_col_idx = buffer.find_status_column_index(cols, status_key)

  if not status_col_idx then
    return {}
  end

  local hl_range = buffer.get_highlight_range(widths, status_col_idx)
  local highlights = {}

  for i, row in ipairs(rows) do
    local status = row[status_key]
    local hl_group = table_component.get_status_highlight(status)
    if hl_group then
      table.insert(highlights, {
        row = i - 1, -- 0-indexed for nvim_buf_add_highlight
        start_col = hl_range.start_col,
        end_col = hl_range.end_col,
        hl_group = hl_group,
      })
    end
  end

  return highlights
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

---Render list view to window
---@param win K8sWindow Window to render to
---@param opts { resources: table[], kind: string, restore_cursor?: number }
function M.render(win, opts)
  local window = require("k8s.ui.nui.window")

  -- Prepare content
  local content = M.prepare_content(opts.resources, opts.kind)

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
    local highlights = M.get_status_highlights(opts.kind, content.rows, content.widths)
    for _, hl in ipairs(highlights) do
      window.add_highlight(content_bufnr, hl.hl_group, hl.row, hl.start_col, hl.end_col)
    end
  end

  -- Restore cursor if specified
  if opts.restore_cursor then
    local pos = M.calculate_cursor_position(opts.restore_cursor, content.row_count)
    window.set_cursor(win, pos, 0)
  elseif content.row_count > 0 then
    window.set_cursor(win, 1, 0)
  end
end

return M
