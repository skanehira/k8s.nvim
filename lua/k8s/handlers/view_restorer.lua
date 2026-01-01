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

---Restore a view (main entry point for polymorphic dispatch)
---@param view table
---@param callbacks K8sCallbacks
---@param restore_cursor number|nil
---@param deps? table Optional dependency injection
function M.restore(view, callbacks, restore_cursor, deps)
  deps = deps or {}

  local restorer = restorers[view.type]
  if restorer then
    restorer(view, callbacks, restore_cursor, deps)
  end
end

return M
