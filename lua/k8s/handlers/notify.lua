--- notify.lua - 通知ユーティリティ

local M = {}

---Show info notification
---@param msg string
function M.info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

---Show warning notification
---@param msg string
function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

---Show error notification
---@param msg string
function M.error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

---Show notification for action result
---@param action_type string
---@param kind string
---@param name string
---@param success boolean
---@param error_msg? string
function M.action_result(action_type, kind, name, success, error_msg)
  local actions = require("k8s.handlers.actions")
  local msg = actions.format_result(action_type, kind, name, success, error_msg)

  if success then
    if action_type == "delete" or action_type == "restart" then
      M.warn(msg)
    else
      M.info(msg)
    end
  else
    M.error(msg)
  end
end

return M
