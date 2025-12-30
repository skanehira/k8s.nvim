--- window.lua - NuiPopupウィンドウ管理

local M = {}

-- Layout constants
local HEADER_HEIGHT = 1
local FOOTER_HEIGHT = 1
local MIN_WIDTH = 40
local MIN_HEIGHT = 10
local DEFAULT_WIDTH_PCT = 0.8
local DEFAULT_HEIGHT_PCT = 0.8

---@alias SectionType "header"|"content"|"footer"

---@class K8sWindow
---@field header any NuiPopup instance
---@field content any NuiPopup instance
---@field footer any NuiPopup instance
---@field mounted boolean
---@field size { width: number, height: number }

---Validate section name
---@param section any
---@return boolean
function M.validate_section(section)
  if type(section) ~= "string" then
    return false
  end
  return section == "header" or section == "content" or section == "footer"
end

---Create popup config for a specific section
---@param section SectionType
---@param opts { width: number, height: number }
---@return table config NuiPopup configuration
function M.create_popup_config(section, opts)
  local width = opts.width
  local height = opts.height
  local content_height = height - HEADER_HEIGHT - FOOTER_HEIGHT

  local section_config = {
    header = {
      height = HEADER_HEIGHT,
      row = 1,
    },
    content = {
      height = content_height,
      row = HEADER_HEIGHT + 1,
    },
    footer = {
      height = FOOTER_HEIGHT,
      row = height,
    },
  }

  local cfg = section_config[section]

  return {
    border = "none",
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
---@return table
function M.get_window_options(section)
  local cursorline = section ~= "header" and section ~= "footer"

  return {
    wrap = false,
    number = false,
    relativenumber = false,
    cursorline = cursorline,
  }
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

---Create a new K8sWindow instance
---@param opts? { width_pct?: number, height_pct?: number }
---@return K8sWindow
function M.create(opts)
  opts = opts or {}

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  local size = M.calculate_popup_size(screen_width, screen_height, opts)
  local center = M.get_center_position(screen_width, screen_height, size.width, size.height)

  -- Create header popup
  local header_config = M.create_popup_config("header", size)
  header_config.relative = "editor"
  header_config.position = {
    row = center.row,
    col = center.col,
  }
  header_config.win_options = M.get_window_options("header")
  header_config.buf_options = M.get_buffer_options()

  -- Create content popup
  local content_config = M.create_popup_config("content", size)
  content_config.relative = "editor"
  content_config.position = {
    row = center.row + HEADER_HEIGHT,
    col = center.col,
  }
  content_config.win_options = M.get_window_options("content")
  content_config.buf_options = M.get_buffer_options()

  -- Create footer popup
  local footer_config = M.create_popup_config("footer", size)
  footer_config.relative = "editor"
  footer_config.position = {
    row = center.row + size.height - FOOTER_HEIGHT,
    col = center.col,
  }
  footer_config.win_options = M.get_window_options("footer")
  footer_config.buf_options = M.get_buffer_options()

  local PopupClass = get_popup()
  return {
    header = PopupClass(header_config),
    content = PopupClass(content_config),
    footer = PopupClass(footer_config),
    mounted = false,
    size = size,
  }
end

---Mount the window (display it)
---@param win K8sWindow
function M.mount(win)
  if win.mounted then
    return
  end

  win.header:mount()
  win.content:mount()
  win.footer:mount()
  win.mounted = true

  -- Focus on content window
  if win.content.winid then
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
  win.content:unmount()
  win.footer:unmount()
  win.mounted = false
end

---Check if window is mounted
---@param win K8sWindow
---@return boolean
function M.is_mounted(win)
  return win.mounted == true
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

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
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

  vim.api.nvim_buf_add_highlight(bufnr, -1, hl_group, line, col_start, col_end)
end

---Map a key in the content buffer
---@param win K8sWindow
---@param key string
---@param callback function
---@param opts? { desc?: string }
function M.map_key(win, key, callback, opts)
  opts = opts or {}
  local bufnr = M.get_content_bufnr(win)
  if not bufnr then
    return
  end

  vim.keymap.set("n", key, callback, {
    buffer = bufnr,
    noremap = true,
    silent = true,
    desc = opts.desc,
  })
end

---Setup close handlers (q and <Esc>)
---@param win K8sWindow
---@param on_close function
function M.setup_close_handlers(win, on_close)
  M.map_key(win, "q", on_close, { desc = "Close" })
  M.map_key(win, "<Esc>", on_close, { desc = "Close" })
end

return M
