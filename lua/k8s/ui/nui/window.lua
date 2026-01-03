--- window.lua - NuiPopupウィンドウ管理

local M = {}

-- Highlight namespace
local hl_ns = vim.api.nvim_create_namespace("k8s")

-- Layout constants
local HEADER_HEIGHT = 1
local TABLE_HEADER_HEIGHT = 1
local FOOTER_HEIGHT = 1
local MIN_WIDTH = 40
local MIN_HEIGHT = 10
local DEFAULT_WIDTH_PCT = 0.8
local DEFAULT_HEIGHT_PCT = 0.8

---@alias SectionType "header"|"table_header"|"content"|"footer"

---@alias ViewType "list"|"detail"

---@class K8sWindow
---@field header any NuiPopup instance
---@field table_header any|nil NuiPopup instance (nil for detail view)
---@field content any NuiPopup instance
---@field footer any NuiPopup instance
---@field mounted boolean
---@field size { width: number, height: number }
---@field view_type ViewType

---Validate section name
---@param section any
---@return boolean
function M.validate_section(section)
  if type(section) ~= "string" then
    return false
  end
  return section == "header" or section == "table_header" or section == "content" or section == "footer"
end

-- Border characters for single style: top-left, top, top-right, right, bottom-right, bottom, bottom-left, left
local border_chars = {
  -- Header: top + sides + bottom separator
  header = { "┌", "─", "┐", "│", "┤", "─", "├", "│" },
  -- Table header: sides only (left and right)
  table_header = { "", "", "", "│", "", "", "", "│" },
  -- Content: sides + bottom separator
  content = { "", "", "", "│", "┤", "─", "├", "│" },
  -- Footer: sides + bottom
  footer = { "", "", "", "│", "┘", "─", "└", "│" },
}

-- Border rows: header top (1) + header bottom sep (1) + content bottom sep (1) + footer bottom (1) = 4
local BORDER_ROWS = 4

---Create popup config for a specific section
---@param section SectionType
---@param opts { width: number, height: number }
---@return table config NuiPopup configuration
function M.create_popup_config(section, opts)
  local width = opts.width
  local height = opts.height
  local content_height = height - HEADER_HEIGHT - TABLE_HEADER_HEIGHT - FOOTER_HEIGHT - BORDER_ROWS

  local section_config = {
    header = {
      height = HEADER_HEIGHT,
      row = 1,
    },
    table_header = {
      height = TABLE_HEADER_HEIGHT,
      row = HEADER_HEIGHT + 1,
    },
    content = {
      height = content_height,
      row = HEADER_HEIGHT + TABLE_HEADER_HEIGHT + 1,
    },
    footer = {
      height = FOOTER_HEIGHT,
      row = height,
    },
  }

  local cfg = section_config[section]

  return {
    border = {
      style = border_chars[section],
    },
    size = {
      width = width,
      height = cfg.height,
    },
    position = {
      row = cfg.row,
      col = 0,
    },
  }
end

---Create initial window state
---@return table state Window state
function M.create_window_state()
  return {
    mounted = false,
    header = nil,
    table_header = nil,
    content = nil,
    footer = nil,
  }
end

---Calculate center position for popup
---@param screen_width number
---@param screen_height number
---@param popup_width number
---@param popup_height number
---@return { col: number, row: number }
function M.get_center_position(screen_width, screen_height, popup_width, popup_height)
  local col = math.max(0, math.floor((screen_width - popup_width) / 2))
  local row = math.max(0, math.floor((screen_height - popup_height) / 2))
  return { col = col, row = row }
end

---Calculate popup size based on screen dimensions
---@param screen_width number
---@param screen_height number
---@param opts? { width_pct?: number, height_pct?: number }
---@return { width: number, height: number }
function M.calculate_popup_size(screen_width, screen_height, opts)
  opts = opts or {}
  local width_pct = opts.width_pct or DEFAULT_WIDTH_PCT
  local height_pct = opts.height_pct or DEFAULT_HEIGHT_PCT

  local width = math.floor(screen_width * width_pct)
  local height = math.floor(screen_height * height_pct)

  -- Enforce minimum size
  width = math.max(MIN_WIDTH, width)
  height = math.max(MIN_HEIGHT, height)

  return { width = width, height = height }
end

---Get buffer options
---@param opts? { modifiable?: boolean }
---@return table
function M.get_buffer_options(opts)
  opts = opts or {}
  return {
    buftype = "nofile",
    swapfile = false,
    modifiable = opts.modifiable or false,
  }
end

---Get window options
---@param section? SectionType
---@param opts? { transparent?: boolean }
---@return table
function M.get_window_options(section, opts)
  opts = opts or {}
  -- Only content section has cursorline
  local cursorline = section == "content"

  local win_opts = {
    wrap = false,
    number = false,
    relativenumber = false,
    cursorline = cursorline,
  }

  -- Set transparent background if enabled
  if opts.transparent then
    win_opts.winhighlight = "Normal:K8sNormal,CursorLine:K8sCursorLine"
  end

  return win_opts
end

-- =============================================================================
-- nui.nvim Integration (実際のUI表示)
-- =============================================================================

-- Lazy load nui.popup to avoid issues in test environments
local Popup = nil
local function get_popup()
  if not Popup then
    Popup = require("nui.popup")
  end
  return Popup
end

---Create a list view window (header + table_header + content + footer)
---@param opts? { width_pct?: number, height_pct?: number, transparent?: boolean }
---@return K8sWindow
function M.create_list_view(opts)
  opts = opts or {}

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  local size = M.calculate_popup_size(screen_width, screen_height, opts)
  local center = M.get_center_position(screen_width, screen_height, size.width, size.height)

  -- content_height for position calculation (with table_header)
  local content_height = size.height - HEADER_HEIGHT - TABLE_HEADER_HEIGHT - FOOTER_HEIGHT - BORDER_ROWS

  -- Create header popup (top border + bottom separator)
  local header_config = M.create_popup_config("header", size)
  header_config.relative = "editor"
  header_config.position = {
    row = center.row,
    col = center.col,
  }
  header_config.win_options = M.get_window_options("header", opts)
  header_config.buf_options = M.get_buffer_options()

  -- Create table header popup (sides only border)
  -- Position: after header top border (1) + header content (1) + header bottom sep (1) = 3
  local table_header_config = M.create_popup_config("table_header", size)
  table_header_config.relative = "editor"
  table_header_config.position = {
    row = center.row + HEADER_HEIGHT + 2,
    col = center.col,
  }
  table_header_config.win_options = M.get_window_options("table_header", opts)
  table_header_config.buf_options = M.get_buffer_options()

  -- Create content popup (bottom separator)
  -- Position: after table_header
  local content_config = M.create_popup_config("content", size)
  content_config.relative = "editor"
  content_config.position = {
    row = center.row + HEADER_HEIGHT + 2 + TABLE_HEADER_HEIGHT,
    col = center.col,
  }
  content_config.win_options = M.get_window_options("content", opts)
  content_config.buf_options = M.get_buffer_options()

  -- Create footer popup (bottom border)
  -- Position: after content + content bottom sep (1)
  local footer_config = M.create_popup_config("footer", size)
  footer_config.relative = "editor"
  footer_config.position = {
    row = center.row + HEADER_HEIGHT + 2 + TABLE_HEADER_HEIGHT + content_height + 1,
    col = center.col,
  }
  footer_config.win_options = M.get_window_options("footer", opts)
  footer_config.buf_options = M.get_buffer_options()

  local PopupClass = get_popup()
  return {
    header = PopupClass(header_config),
    table_header = PopupClass(table_header_config),
    content = PopupClass(content_config),
    footer = PopupClass(footer_config),
    mounted = false,
    size = size,
    view_type = "list",
  }
end

-- Border characters for detail view (no table_header)
local detail_border_chars = {
  header = { "┌", "─", "┐", "│", "┤", "─", "├", "│" },
  content = { "", "", "", "│", "┤", "─", "├", "│" },
  footer = { "", "", "", "│", "┘", "─", "└", "│" },
}

-- Border rows for detail view: header top (1) + header bottom sep (1) + content bottom sep (1) + footer bottom (1) = 4
local DETAIL_BORDER_ROWS = 4

---Create a detail view window (header + content + footer, no table_header)
---@param opts? { width_pct?: number, height_pct?: number, transparent?: boolean }
---@return K8sWindow
function M.create_detail_view(opts)
  opts = opts or {}

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  local size = M.calculate_popup_size(screen_width, screen_height, opts)
  local center = M.get_center_position(screen_width, screen_height, size.width, size.height)

  -- content_height for detail view (no table_header)
  local content_height = size.height - HEADER_HEIGHT - FOOTER_HEIGHT - DETAIL_BORDER_ROWS

  -- Create header popup
  local header_config = {
    border = { style = detail_border_chars.header },
    size = { width = size.width, height = HEADER_HEIGHT },
    relative = "editor",
    position = { row = center.row, col = center.col },
    win_options = M.get_window_options("header", opts),
    buf_options = M.get_buffer_options(),
  }

  -- Create content popup (directly after header)
  local content_config = {
    border = { style = detail_border_chars.content },
    size = { width = size.width, height = content_height },
    relative = "editor",
    position = {
      row = center.row + HEADER_HEIGHT + 2, -- after header top border + content + bottom sep
      col = center.col,
    },
    win_options = M.get_window_options("content", opts),
    buf_options = M.get_buffer_options(),
  }

  -- Create footer popup
  local footer_config = {
    border = { style = detail_border_chars.footer },
    size = { width = size.width, height = FOOTER_HEIGHT },
    relative = "editor",
    position = {
      row = center.row + HEADER_HEIGHT + 2 + content_height + 1, -- after content + bottom sep
      col = center.col,
    },
    win_options = M.get_window_options("footer", opts),
    buf_options = M.get_buffer_options(),
  }

  local PopupClass = get_popup()
  return {
    header = PopupClass(header_config),
    table_header = nil, -- No table_header for detail view
    content = PopupClass(content_config),
    footer = PopupClass(footer_config),
    mounted = false,
    size = size,
    view_type = "detail",
  }
end

---Create a new K8sWindow instance (alias for create_list_view for backward compatibility)
---@param opts? { width_pct?: number, height_pct?: number, transparent?: boolean }
---@return K8sWindow
function M.create(opts)
  return M.create_list_view(opts)
end

---Mount the window (display it)
---@param win K8sWindow
function M.mount(win)
  if win.mounted then
    return
  end

  win.header:mount()
  if win.table_header then
    win.table_header:mount()
  end
  win.content:mount()
  win.footer:mount()
  win.mounted = true

  -- Focus on content window (check validity first)
  if win.content.winid and vim.api.nvim_win_is_valid(win.content.winid) then
    vim.api.nvim_set_current_win(win.content.winid)
  end
end

---Unmount the window (hide it)
---@param win K8sWindow
function M.unmount(win)
  if not win.mounted then
    return
  end

  win.header:unmount()
  if win.table_header then
    win.table_header:unmount()
  end
  win.content:unmount()
  win.footer:unmount()
  win.mounted = false
end

---Hide the window (keep buffers)
---@param win K8sWindow
function M.hide(win)
  if not win.mounted then
    return
  end

  win.header:hide()
  if win.table_header then
    win.table_header:hide()
  end
  win.content:hide()
  win.footer:hide()
end

---Show the window
---@param win K8sWindow
function M.show(win)
  if not win.mounted then
    return
  end

  win.header:show()
  if win.table_header then
    win.table_header:show()
  end
  win.content:show()
  win.footer:show()

  -- Focus on content window (check validity first)
  if win.content.winid and vim.api.nvim_win_is_valid(win.content.winid) then
    vim.api.nvim_set_current_win(win.content.winid)
  end
end

---Hide table header section
---@param win K8sWindow
function M.hide_table_header(win)
  if win.table_header then
    win.table_header:hide()
  end
end

---Show table header section
---@param win K8sWindow
function M.show_table_header(win)
  if win.table_header then
    win.table_header:show()
  end
end

---Check if window is mounted
---@param win K8sWindow
---@return boolean
function M.is_mounted(win)
  return win.mounted == true
end

---Check if window buffers are valid
---@param win K8sWindow
---@return boolean
function M.has_valid_buffers(win)
  local content_bufnr = M.get_content_bufnr(win)
  if not content_bufnr or not vim.api.nvim_buf_is_valid(content_bufnr) then
    return false
  end
  return true
end

---Check if window is visible (mounted and winid is valid)
---@param win K8sWindow
---@return boolean
function M.is_visible(win)
  if not win.mounted then
    return false
  end
  -- Check if content window is valid and visible
  if win.content and win.content.winid then
    return vim.api.nvim_win_is_valid(win.content.winid)
  end
  return false
end

---Get content buffer number
---@param win K8sWindow
---@return number|nil
function M.get_content_bufnr(win)
  if win.content and win.content.bufnr then
    return win.content.bufnr
  end
  return nil
end

---Get header buffer number
---@param win K8sWindow
---@return number|nil
function M.get_header_bufnr(win)
  if win.header and win.header.bufnr then
    return win.header.bufnr
  end
  return nil
end

---Get table header buffer number
---@param win K8sWindow
---@return number|nil
function M.get_table_header_bufnr(win)
  if win.table_header and win.table_header.bufnr then
    return win.table_header.bufnr
  end
  return nil
end

---Get footer buffer number
---@param win K8sWindow
---@return number|nil
function M.get_footer_bufnr(win)
  if win.footer and win.footer.bufnr then
    return win.footer.bufnr
  end
  return nil
end

---Set cursor position in content window
---@param win K8sWindow
---@param row number 1-indexed row
---@param col? number 0-indexed column (default 0)
function M.set_cursor(win, row, col)
  col = col or 0
  if win.content and win.content.winid and vim.api.nvim_win_is_valid(win.content.winid) then
    vim.api.nvim_win_set_cursor(win.content.winid, { row, col })
  end
end

---Get cursor position in content window
---@param win K8sWindow
---@return number row, number col
function M.get_cursor(win)
  if win.content and win.content.winid and vim.api.nvim_win_is_valid(win.content.winid) then
    local pos = vim.api.nvim_win_get_cursor(win.content.winid)
    return pos[1], pos[2]
  end
  return 1, 0
end

---Set lines in a buffer
---@param bufnr number
---@param lines string[]
function M.set_lines(bufnr, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

---Add highlight to buffer
---@param bufnr number
---@param hl_group string
---@param line number 0-indexed
---@param col_start number
---@param col_end number
function M.add_highlight(bufnr, hl_group, line, col_start, col_end)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.hl.range(bufnr, hl_ns, hl_group, { line, col_start }, { line, col_end })
end

---Map a key in the content buffer
---@param win K8sWindow
---@param key string
---@param callback function
---@param opts? { desc?: string }
function M.map_key(win, key, callback, opts)
  opts = opts or {}
  local bufnr = M.get_content_bufnr(win)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.keymap.set("n", key, callback, {
    buffer = bufnr,
    noremap = true,
    silent = true,
    desc = opts.desc,
  })
end

---Setup close handlers (q and <C-h>)
---@param win K8sWindow
---@param on_close function
function M.setup_close_handlers(win, on_close)
  M.map_key(win, "q", on_close, { desc = "Close" })
  M.map_key(win, "<C-h>", on_close, { desc = "Close" })
end

return M
