--- view_helper.lua - ビュー初期化ヘルパー

local M = {}

---@class ViewConfig
---@field view_type "list"|"detail"
---@field transparent? boolean
---@field header { context: string, namespace: string, view: string, loading?: boolean }
---@field footer_view_type string
---@field footer_kind? string
---@field view_stack_entry table
---@field initial_content? string[]
---@field on_mounted? fun(win: K8sWindow)
---@field pre_render? boolean

---Create view config with defaults
---@param opts table
---@return ViewConfig
function M.create_view_config(opts)
  return {
    view_type = opts.view_type,
    transparent = opts.transparent or false,
    header = opts.header,
    footer_view_type = opts.footer_view_type,
    footer_kind = opts.footer_kind,
    view_stack_entry = opts.view_stack_entry,
    initial_content = opts.initial_content,
    on_mounted = opts.on_mounted,
    pre_render = opts.pre_render or false,
  }
end

---Validate view config
---@param config ViewConfig
---@return boolean valid
---@return string|nil error
function M.validate_config(config)
  if not config.view_type then
    return false, "view_type is required"
  end

  if config.view_type ~= "list" and config.view_type ~= "detail" then
    return false, "view_type must be 'list' or 'detail'"
  end

  if not config.header then
    return false, "header is required"
  end

  if not config.footer_view_type then
    return false, "footer_view_type is required"
  end

  if not config.view_stack_entry then
    return false, "view_stack_entry is required"
  end

  return true, nil
end

---Get current cursor position from window
---@param win K8sWindow|nil
---@param window_module table
---@return number
function M.get_current_cursor(win, window_module)
  if not win then
    return 1
  end
  return window_module.get_cursor(win)
end

---Prepare header content
---@param header { context: string, namespace: string, view: string, loading?: boolean }
---@param buffer_module table
---@return string
function M.prepare_header_content(header, buffer_module)
  return buffer_module.create_header_content(header)
end

---Prepare footer content
---@param view_type string
---@param kind string|nil
---@param buffer_module table
---@param callbacks table
---@return string
function M.prepare_footer_content(view_type, kind, buffer_module, callbacks)
  local keymaps = callbacks.get_footer_keymaps(view_type, kind)
  return buffer_module.create_footer_content(keymaps)
end

---Create and mount a new view window
---@param config ViewConfig
---@param callbacks table
---@return K8sWindow
function M.create_view(config, callbacks)
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")
  local view_stack = require("k8s.core.view_stack")

  -- Get current window and cursor position
  local prev_window = global_state.get_window()
  local cursor_row = M.get_current_cursor(prev_window, window)

  -- Create new window
  local new_window
  if config.view_type == "list" then
    new_window = window.create_list_view({ transparent = config.transparent })
  else
    new_window = window.create_detail_view({ transparent = config.transparent })
  end

  -- Pre-render pattern: write content before mount
  if config.pre_render then
    M._write_buffers_before_mount(new_window, config, buffer, callbacks)
  end

  -- Mount window
  window.mount(new_window)

  -- Setup keymaps
  callbacks.setup_keymaps_for_window(new_window)

  -- Update global window reference
  global_state.set_window(new_window)

  -- Push to view stack
  local vs = global_state.get_view_stack() or {}
  local entry = vim.tbl_deep_extend("force", config.view_stack_entry, {
    parent_cursor = cursor_row,
    window = new_window,
  })
  global_state.set_view_stack(view_stack.push(vs, entry))

  -- Hide previous window
  if prev_window then
    window.hide(prev_window)
  end

  -- Post-render pattern: write content after mount (if not pre-rendered)
  if not config.pre_render then
    M._write_buffers_after_mount(new_window, config, buffer, callbacks)
  end

  -- Call on_mounted callback
  if config.on_mounted then
    config.on_mounted(new_window)
  end

  return new_window
end

---Write content to buffers before mount
---@param win K8sWindow
---@param config ViewConfig
---@param buffer_module table
---@param callbacks table
function M._write_buffers_before_mount(win, config, buffer_module, callbacks)
  local window = require("k8s.ui.nui.window")

  -- Header
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = M.prepare_header_content(config.header, buffer_module)
    window.set_lines(header_bufnr, { header_content })
  end

  -- Table header (only for list view)
  if config.view_type == "list" then
    local table_header_bufnr = window.get_table_header_bufnr(win)
    if table_header_bufnr then
      window.set_lines(table_header_bufnr, { "" })
    end
  end

  -- Content
  local content_bufnr = window.get_content_bufnr(win)
  if content_bufnr then
    local content = config.initial_content or { "Loading..." }
    window.set_lines(content_bufnr, content)
  end

  -- Footer
  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local footer_content = M.prepare_footer_content(
      config.footer_view_type,
      config.footer_kind,
      buffer_module,
      callbacks
    )
    window.set_lines(footer_bufnr, { footer_content })
  end
end

---Write content to buffers after mount
---@param win K8sWindow
---@param config ViewConfig
---@param buffer_module table
---@param callbacks table
function M._write_buffers_after_mount(win, config, buffer_module, callbacks)
  local window = require("k8s.ui.nui.window")

  -- Content (if provided)
  if config.initial_content then
    local content_bufnr = window.get_content_bufnr(win)
    if content_bufnr then
      window.set_lines(content_bufnr, config.initial_content)
    end
  end

  -- Header
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = M.prepare_header_content(config.header, buffer_module)
    window.set_lines(header_bufnr, { header_content })
  end

  -- Footer
  callbacks.render_footer(config.footer_view_type, config.footer_kind)
end

return M
