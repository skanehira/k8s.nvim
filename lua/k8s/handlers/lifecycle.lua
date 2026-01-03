--- lifecycle.lua - View lifecycle management
--- Manages view push/pop with proper on_mounted/on_unmounted callbacks

local M = {}

---@alias SetupKeymapsCallback fun(win: K8sWindow)

---Call on_unmounted callback for view
---@param view ViewState|nil
function M.call_on_unmounted(view)
  if view and view.on_unmounted then
    view.on_unmounted(view)
  end
end

---Call on_mounted callback for view
---@param view ViewState|nil
function M.call_on_mounted(view)
  if view and view.on_mounted then
    view.on_mounted(view)
  end
end

---Push a new view to stack with proper lifecycle management
---@param new_view ViewState
---@param setup_keymaps SetupKeymapsCallback
function M.push_view(new_view, setup_keymaps)
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  -- Get current view and call on_unmounted
  local current_view = state.get_current_view()
  if current_view then
    M.call_on_unmounted(current_view)

    -- Save current cursor position
    local current_win = current_view.window or state.get_window()
    if current_win and window.is_mounted(current_win) then
      local cursor_pos = window.get_cursor(current_win)
      state.save_current_view_state(cursor_pos, current_win)
      window.hide(current_win)
    end
  end

  -- Push new view to stack
  state.push_view(new_view)
  state.set_window(new_view.window)

  -- Setup keymaps for new view
  setup_keymaps(new_view.window)

  -- Call on_mounted for new view
  M.call_on_mounted(new_view)
end

---Pop current view from stack with proper lifecycle management
---@param setup_keymaps SetupKeymapsCallback
function M.pop_view(setup_keymaps)
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local render = require("k8s.handlers.render")

  if not state.can_pop_view() then
    return
  end

  -- Get current view and call on_unmounted
  local current_view = state.get_current_view()
  if current_view then
    M.call_on_unmounted(current_view)

    -- Unmount current window
    local current_win = current_view.window
    if current_win then
      window.unmount(current_win)
    end
  end

  -- Pop view from stack
  state.pop_view()

  -- Get previous view (now current) and restore
  local prev_view = state.get_current_view()
  if not prev_view then
    return
  end

  -- Show or recreate previous window
  local prev_win = prev_view.window
  local config = state.get_config() or {}

  if prev_win and window.is_mounted(prev_win) and window.has_valid_buffers(prev_win) then
    -- Render before show to prevent stale content flash
    render.render()
    window.show(prev_win)
  else
    -- Recreate window based on view type
    if state.is_list_view(prev_view.type) then
      prev_win = window.create_list_view({ transparent = config.transparent })
    else
      prev_win = window.create_detail_view({ transparent = config.transparent })
    end
    window.mount(prev_win)

    -- Update view with new window reference
    state.update_view(function(v)
      return vim.tbl_extend("force", v, { window = prev_win })
    end)

    -- Render after mount
    render.render()
  end

  state.set_window(prev_win)

  -- Setup keymaps
  setup_keymaps(prev_win)

  -- Restore cursor position
  if prev_view.cursor then
    window.set_cursor(prev_win, prev_view.cursor)
  end

  -- Call on_mounted for previous view
  M.call_on_mounted(prev_view)
end

---Push a detail view with a new window using lifecycle management
---@param view_state ViewState View state to push (must have on_mounted, on_unmounted, render)
---@param setup_keymaps SetupKeymapsCallback
function M.push_detail_view(view_state, setup_keymaps)
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local render = require("k8s.handlers.render")
  local config = state.get_config() or {}

  -- Create new detail view window
  local new_win = window.create_detail_view({ transparent = config.transparent })
  window.mount(new_win)

  -- Store window reference in view state
  view_state.window = new_win

  -- Use lifecycle-aware push
  M.push_view(view_state, setup_keymaps)

  -- Render immediately
  render.render()
end

return M
