--- update_loop.lua - 更新ループ管理

local M = {}

local MAX_RETRY_DELAY = 30000 -- 30 seconds
local BASE_RETRY_DELAY = 1000 -- 1 second

---Create initial update loop state
---@return table state
function M.create_state()
  return {
    loading = false,
    last_update = nil,
    error = nil,
  }
end

---Set loading state (immutable)
---@param state table
---@param loading boolean
---@return table new_state
function M.set_loading(state, loading)
  return {
    loading = loading,
    last_update = state.last_update,
    error = state.error,
  }
end

---Set error state (immutable)
---@param state table
---@param error_msg string
---@return table new_state
function M.set_error(state, error_msg)
  return {
    loading = false,
    last_update = state.last_update,
    error = error_msg,
  }
end

---Clear error (immutable)
---@param state table
---@return table new_state
function M.clear_error(state)
  return {
    loading = state.loading,
    last_update = state.last_update,
    error = nil,
  }
end

---Set last update time (immutable)
---@param state table
---@param timestamp number
---@return table new_state
function M.set_last_update(state, timestamp)
  return {
    loading = false,
    last_update = timestamp,
    error = state.error,
  }
end

---Check if update should be triggered
---@param state table
---@param interval_ms number
---@return boolean
function M.should_update(state, interval_ms)
  if state.loading then
    return false
  end

  if state.last_update == nil then
    return true
  end

  local now = os.time()
  local interval_sec = interval_ms / 1000
  return (now - state.last_update) >= interval_sec
end

---Format error message for display
---@param error_msg string
---@return string
function M.format_error_message(error_msg)
  return string.format("Error: %s", error_msg)
end

---Get retry delay with exponential backoff
---@param attempt number
---@return number delay_ms
function M.get_retry_delay(attempt)
  local delay = BASE_RETRY_DELAY * math.pow(2, attempt - 1)
  return math.min(delay, MAX_RETRY_DELAY)
end

return M
