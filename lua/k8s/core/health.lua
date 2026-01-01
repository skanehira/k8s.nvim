--- health.lua - ヘルスチェック

local M = {}

---Check if kubectl is available
---@return boolean found
function M.check_kubectl()
  return vim.fn.executable("kubectl") == 1
end

return M
