--- timer.lua - 自動更新タイマー管理

local M = {}

---Start auto-refresh timer
---@param on_refresh function Callback to call on refresh
function M.start_auto_refresh(on_refresh)
  local global_state = require("k8s.core.global_state")

  -- Don't start if already running
  if global_state.get_timer() then
    return
  end

  local config = global_state.get_config()
  local interval = config and config.refresh_interval or 5000

  -- Use vim.uv (libuv) for timer
  local timer = vim.uv.new_timer()
  if not timer then
    return
  end

  timer:start(
    interval,
    interval,
    vim.schedule_wrap(function()
      local win = global_state.get_window()
      if not win then
        return
      end

      local window = require("k8s.ui.nui.window")
      if not window.is_mounted(win) then
        return
      end

      local view_stack_mod = require("k8s.core.view_stack")
      local vs = global_state.get_view_stack()
      local current = view_stack_mod.current(vs)

      -- Only auto-refresh in list view and ensure window matches
      if current and current.type == "list" and current.window == win then
        on_refresh()
      end
    end)
  )

  global_state.set_timer(timer)
end

---Stop auto-refresh timer
function M.stop_auto_refresh()
  local global_state = require("k8s.core.global_state")
  local timer = global_state.get_timer()

  if timer then
    timer:stop()
    timer:close()
    global_state.set_timer(nil)
  end
end

return M
