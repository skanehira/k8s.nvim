--- autocmd.lua - オートコマンド定義

local M = {}

-- Events that trigger cleanup
local cleanup_events = {
  VimLeavePre = true,
  TabClosed = true,
}

---Get autocmd group name
---@return string
function M.get_group_name()
  return "k8s_nvim"
end

---Get autocmd definitions
---@return table[]
function M.get_autocmd_definitions()
  return {
    {
      event = "VimLeavePre",
      pattern = "*",
      desc = M.format_autocmd_desc("cleanup all port forwards"),
    },
    {
      event = "TabClosed",
      pattern = "*",
      desc = M.format_autocmd_desc("cleanup tab resources"),
    },
  }
end

---Create cleanup callback
---@return function
function M.create_cleanup_callback()
  return function()
    -- Cleanup logic will be implemented here
    -- For now, return an empty function
  end
end

---Check if event should trigger cleanup
---@param event string
---@return boolean
function M.should_cleanup_on_event(event)
  return cleanup_events[event] == true
end

---Format autocmd description
---@param action string
---@return string
function M.format_autocmd_desc(action)
  return string.format("k8s.nvim: %s", action)
end

return M
