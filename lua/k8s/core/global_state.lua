--- global_state.lua - グローバル状態管理モジュール

local M = {}

-- Module state
local state = {
  setup_done = false,
  config = nil,
  window = nil,
  app_state = nil,
  timer = nil,
  view_stack = nil,
  pf_list_connections = nil,
}

-- =============================================================================
-- Generic accessors
-- =============================================================================

---Get state value by key
---@param key string
---@return any
function M.get(key)
  return state[key]
end

---Set state value by key
---@param key string
---@param value any
function M.set(key, value)
  state[key] = value
end

---Reset all state to initial values
function M.reset()
  state.setup_done = false
  state.config = nil
  state.window = nil
  state.app_state = nil
  state.timer = nil
  state.view_stack = nil
  state.pf_list_connections = nil
end

-- =============================================================================
-- Specific accessors for better type safety
-- =============================================================================

---Check if setup is done
---@return boolean
function M.is_setup_done()
  return state.setup_done
end

---Mark setup as done
function M.set_setup_done()
  state.setup_done = true
end

---Get config
---@return table|nil
function M.get_config()
  return state.config
end

---Set config
---@param config table
function M.set_config(config)
  state.config = config
end

---Get current window
---@return K8sWindow|nil
function M.get_window()
  return state.window
end

---Set current window
---@param win K8sWindow|nil
function M.set_window(win)
  state.window = win
end

---Get app state
---@return table|nil
function M.get_app_state()
  return state.app_state
end

---Set app state
---@param app_state table|nil
function M.set_app_state(app_state)
  state.app_state = app_state
end

---Get timer
---@return userdata|nil
function M.get_timer()
  return state.timer
end

---Set timer
---@param timer userdata|nil
function M.set_timer(timer)
  state.timer = timer
end

---Get view stack
---@return table|nil
function M.get_view_stack()
  return state.view_stack
end

---Set view stack
---@param view_stack table|nil
function M.set_view_stack(view_stack)
  state.view_stack = view_stack
end

---Get port forward list connections
---@return table|nil
function M.get_pf_list_connections()
  return state.pf_list_connections
end

---Set port forward list connections
---@param connections table|nil
function M.set_pf_list_connections(connections)
  state.pf_list_connections = connections
end

return M
