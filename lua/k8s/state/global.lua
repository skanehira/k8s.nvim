--- state/global.lua - Global State management

local M = {}

---@class GlobalState
---@field current_context string|nil Current Kubernetes context
---@field current_namespace string Current namespace
---@field setup_done boolean Whether setup is complete
---@field config table|nil Plugin configuration
---@field view_stack table[] View stack
---@field window table|nil Current window reference

---@type GlobalState
local state = {
  current_context = nil,
  current_namespace = "default",
  setup_done = false,
  config = nil,
  view_stack = {},
  window = nil,
}

---Get current global state
---NOTE: Returns shallow copy to preserve window references.
---View objects contain window references that must not be deep copied.
---@return GlobalState
function M.get()
  -- Return shallow copy - view_stack items retain their original references
  return {
    current_context = state.current_context,
    current_namespace = state.current_namespace,
    setup_done = state.setup_done,
    config = state.config and vim.deepcopy(state.config) or nil,
    view_stack = state.view_stack,  -- Keep reference to original stack
    window = state.window,
  }
end

---Update global state with updater function
---@param updater function(state: GlobalState): GlobalState
function M.update(updater)
  state = updater(state)
end

---Reset global state to initial values
function M.reset()
  state = {
    current_context = nil,
    current_namespace = "default",
    setup_done = false,
    config = nil,
    view_stack = {},
    window = nil,
  }
end

return M
