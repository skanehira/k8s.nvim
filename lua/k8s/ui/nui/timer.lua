--- timer.lua - 自動更新タイマー

local M = {}

-- Timer constants
local DEFAULT_INTERVAL = 5000 -- 5 seconds
local MIN_INTERVAL = 500 -- 0.5 seconds
local MAX_INTERVAL = 600000 -- 10 minutes

---Get default interval
---@return number interval in milliseconds
function M.get_default_interval()
  return DEFAULT_INTERVAL
end

---Validate interval value
---@param interval any
---@return boolean
function M.validate_interval(interval)
  if type(interval) ~= "number" then
    return false
  end

  return interval >= MIN_INTERVAL and interval <= MAX_INTERVAL
end

---Create timer configuration
---@param opts? { interval?: number, interval_seconds?: number }
---@return { interval: number, repeat_timer: boolean }
function M.create_timer_config(opts)
  opts = opts or {}

  local interval = DEFAULT_INTERVAL

  if opts.interval then
    interval = opts.interval
  elseif opts.interval_seconds then
    interval = opts.interval_seconds * 1000
  end

  return {
    interval = interval,
    repeat_timer = true,
  }
end

---Create initial timer state
---@return table state
function M.create_timer_state()
  return {
    running = false,
    handle = nil,
    last_tick = nil,
  }
end

---Update timer state immutably
---@param state table
---@param updates table
---@return table new_state
function M.update_timer_state(state, updates)
  local new_state = {
    running = state.running,
    handle = state.handle,
    last_tick = state.last_tick,
  }

  for k, v in pairs(updates) do
    new_state[k] = v
  end

  return new_state
end

---Calculate next tick time
---@param last_tick number
---@param interval number
---@return number next_tick
function M.calculate_next_tick(last_tick, interval)
  return last_tick + interval
end

---Check if it's time to tick
---@param last_tick number|nil
---@param current number
---@param interval number
---@return boolean
function M.should_tick(last_tick, current, interval)
  if last_tick == nil then
    return true
  end

  return current >= last_tick + interval
end

---Create tick callback with error handling
---@param handler function
---@param on_error? function
---@return function
function M.create_tick_callback(handler, on_error)
  return function()
    local ok, err = pcall(handler)
    if not ok and on_error then
      on_error(err)
    end
  end
end

---Format interval for display
---@param interval number in milliseconds
---@return string
function M.format_interval(interval)
  local seconds = math.floor(interval / 1000)

  if seconds < 60 then
    return string.format("%ds", seconds)
  end

  local minutes = math.floor(seconds / 60)
  local remaining_seconds = seconds % 60

  if remaining_seconds == 0 then
    return string.format("%dm", minutes)
  end

  return string.format("%dm %ds", minutes, remaining_seconds)
end

return M
