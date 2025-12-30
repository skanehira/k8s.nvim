--- confirm.lua - 確認ダイアログ（vim.fn.confirm）のヘルパー

local M = {}

---Format confirmation message
---@param action string Action name (delete, restart, etc.)
---@param kind string Resource kind
---@param name string Resource name
---@return string message Confirmation message
function M.format_message(action, kind, name)
  local action_capitalized = action:sub(1, 1):upper() .. action:sub(2)
  return string.format("%s %s/%s?", action_capitalized, kind, name)
end

---Parse vim.fn.confirm response
---@param response number Response from vim.fn.confirm (1=yes, 2=no, 0=cancel)
---@return boolean confirmed User confirmed the action
function M.parse_response(response)
  return response == 1
end

return M
