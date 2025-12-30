--- view_actions.lua - ビューアクション（refresh, help, toggle_secret, port_forward_list）

local M = {}

---Create refresh action
---@return table action
function M.create_refresh_action()
  return {
    type = "refresh",
  }
end

---Create help action
---@return table action
function M.create_help_action()
  return {
    type = "help",
  }
end

---Create toggle secret action
---@return table action
function M.create_toggle_secret_action()
  return {
    type = "toggle_secret",
  }
end

---Create port forward list action
---@return table action
function M.create_port_forward_list_action()
  return {
    type = "port_forward_list",
  }
end

---Check if help is visible
---@param state table
---@return boolean
function M.is_help_visible(state)
  return state.help_visible == true
end

---Check if secrets are masked
---@param state table
---@return boolean
function M.is_secret_masked(state)
  if state.secret_masked == nil then
    return true -- default to masked
  end
  return state.secret_masked
end

---Toggle help state
---@param state table
---@return table new_state
function M.toggle_help_state(state)
  return {
    help_visible = not state.help_visible,
    secret_masked = state.secret_masked,
  }
end

---Toggle secret mask state
---@param state table
---@return table new_state
function M.toggle_secret_state(state)
  return {
    help_visible = state.help_visible,
    secret_masked = not state.secret_masked,
  }
end

---Get view action keymaps
---@return table[]
function M.get_view_action_keymaps()
  return {
    { key = "R", action = "refresh", desc = "Refresh" },
    { key = "?", action = "help", desc = "Toggle help" },
    { key = "S", action = "toggle_secret", desc = "Toggle secret mask" },
    { key = "P", action = "port_forward_list", desc = "Port forwards" },
  }
end

return M
