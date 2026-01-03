--- render.lua - Centralized rendering manager
--- All UI updates flow through this module

local M = {}
local render_timer = nil
local DEBOUNCE_MS = 100

---Internal render function that reads from state and renders
local function do_render()
  local state = require("k8s.state")
  local window_mod = require("k8s.ui.nui.window")

  local view = state.get_current_view()
  local win = state.get_window()

  if not view or not win or not view.render then
    return
  end
  if not window_mod.is_mounted(win) then
    return
  end
  view.render(view, win)
end

---Render the current view
---@param opts? { mode?: "immediate" | "debounced" }
function M.render(opts)
  opts = opts or {}
  local mode = opts.mode or "immediate"

  if mode == "debounced" then
    if render_timer then
      render_timer:stop()
    end
    ---@diagnostic disable-next-line: undefined-field
    render_timer = vim.uv.new_timer()
    render_timer:start(
      DEBOUNCE_MS,
      0,
      vim.schedule_wrap(function()
        render_timer:stop()
        render_timer:close()
        render_timer = nil
        do_render()
      end)
    )
    return
  end

  do_render()
end

return M
