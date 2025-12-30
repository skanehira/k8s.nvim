--- view_restorer.lua - ビュー復帰処理（ポリモーフィズムパターン）

local M = {}

-- View type specific restorers
local restorers = {}

---List view restorer
---@param view table
---@param callbacks K8sCallbacks
---@param restore_cursor number|nil
---@param deps table
restorers.list = function(view, callbacks, restore_cursor, deps)
  local global_state = deps.global_state or require("k8s.core.global_state")
  local app = deps.app or require("k8s.core.state")
  local window = deps.window or require("k8s.ui.nui.window")

  local app_state = global_state.get_app_state()
  local kind = view.kind or (app_state and app_state.current_kind)

  callbacks.render_footer("list", kind)

  -- Restore the kind if different
  if view.kind and app_state and view.kind ~= app_state.current_kind then
    global_state.set_app_state(app.set_kind(app_state, view.kind))
    -- Re-fetch and render for the previous kind
    callbacks.fetch_and_render(view.kind, app_state.current_namespace, { restore_cursor = restore_cursor })
  elseif restore_cursor and view.window then
    window.set_cursor(view.window, restore_cursor, 0)
  end
end

---Describe view restorer
---@param view table
---@param callbacks K8sCallbacks
---@param restore_cursor number|nil
---@param deps table
restorers.describe = function(view, callbacks, restore_cursor, deps)
  local window = deps.window or require("k8s.ui.nui.window")

  local kind = view.resource and view.resource.kind
  callbacks.render_footer("describe", kind)

  if restore_cursor and view.window then
    window.set_cursor(view.window, restore_cursor, 0)
  end
end

---Help view restorer
---@param view table
---@param callbacks K8sCallbacks
---@param restore_cursor number|nil
---@param deps table
restorers.help = function(view, callbacks, restore_cursor, deps)
  local window = deps.window or require("k8s.ui.nui.window")

  callbacks.render_footer("help")

  if restore_cursor and view.window then
    window.set_cursor(view.window, restore_cursor, 0)
  end
end

---Port forward list view restorer
---@param view table
---@param callbacks K8sCallbacks
---@param restore_cursor number|nil
---@param deps table
restorers.port_forward_list = function(view, callbacks, restore_cursor, deps)
  local window = deps.window or require("k8s.ui.nui.window")

  callbacks.render_footer("port_forward_list")

  if restore_cursor and view.window then
    window.set_cursor(view.window, restore_cursor, 0)
  end
end

---Get restorer function for a view type
---@param view_type string
---@return function|nil
function M.get_restorer(view_type)
  return restorers[view_type]
end

---Get footer parameters for a view
---@param view table
---@param app_state table|nil
---@return string view_type
---@return string|nil kind
function M.get_footer_params(view, app_state)
  if view.type == "list" then
    local kind = view.kind or (app_state and app_state.current_kind)
    return "list", kind
  elseif view.type == "describe" then
    local kind = view.resource and view.resource.kind
    return "describe", kind
  elseif view.type == "help" then
    return "help", nil
  elseif view.type == "port_forward_list" then
    return "port_forward_list", nil
  end

  return view.type, nil
end

---Check if view needs refetch when restoring
---@param view table
---@param app_state table|nil
---@return boolean
function M.needs_refetch(view, app_state)
  if view.type ~= "list" then
    return false
  end

  if not view.kind or not app_state then
    return false
  end

  return view.kind ~= app_state.current_kind
end

---Restore a view (main entry point for polymorphic dispatch)
---@param view table
---@param callbacks K8sCallbacks
---@param restore_cursor number|nil
---@param deps? table Optional dependency injection
function M.restore(view, callbacks, restore_cursor, deps)
  deps = deps or {}

  local restorer = M.get_restorer(view.type)
  if restorer then
    restorer(view, callbacks, restore_cursor, deps)
  end
end

return M
