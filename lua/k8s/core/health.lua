--- health.lua - ヘルスチェック

local M = {}

-- Required executables
local required_executables = {
  "kubectl",
}

---Create check result
---@param ok boolean
---@param message string
---@return table result
function M.create_check_result(ok, message)
  return {
    ok = ok,
    message = message,
  }
end

---Get list of required executables
---@return string[]
function M.get_required_executables()
  return required_executables
end

---Format check message
---@param executable string
---@param found boolean
---@return string
function M.format_check_message(executable, found)
  if found then
    return string.format("✓ %s found", executable)
  else
    return string.format("✗ %s not found", executable)
  end
end

---Get overall health status
---@param checks table[]
---@return "healthy"|"unhealthy"
function M.get_health_status(checks)
  for _, check in ipairs(checks) do
    if not check.ok then
      return "unhealthy"
    end
  end
  return "healthy"
end

---Format health report
---@param checks table[]
---@return string
function M.format_health_report(checks)
  local lines = { "k8s.nvim Health Check:", "" }

  for _, check in ipairs(checks) do
    table.insert(lines, check.message)
  end

  local status = M.get_health_status(checks)
  table.insert(lines, "")
  table.insert(lines, string.format("Status: %s", status))

  return table.concat(lines, "\n")
end

---Check if kubectl is available
---@return boolean found
function M.check_kubectl()
  local result = vim.fn.executable("kubectl")
  return result == 1
end

---Run all health checks
---@return table[] checks
function M.run_checks()
  local checks = {}

  for _, executable in ipairs(required_executables) do
    local found = vim.fn.executable(executable) == 1
    table.insert(checks, M.create_check_result(found, M.format_check_message(executable, found)))
  end

  return checks
end

return M
