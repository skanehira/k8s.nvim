--- watcher.lua - kubectl watch process management

local M = {}

---@class WatcherState
---@field job_id number|nil
---@field kind string|nil
---@field namespace string|nil

---@type WatcherState
local state = {
  job_id = nil,
  kind = nil,
  namespace = nil,
}

---@class WatcherCallbacks
---@field on_event fun(event_type: string, resource: table) Called for each event
---@field on_error fun(error: string) Called on error
---@field on_started? fun() Called when watch starts

---Start watching resources
---@param kind string
---@param namespace string
---@param callbacks WatcherCallbacks
function M.start(kind, namespace, callbacks)
  -- Stop existing watch if any
  M.stop()

  local watch_adapter = require("k8s.infra.kubectl.watch_adapter")
  local parser = require("k8s.infra.kubectl.parser")

  state.kind = kind
  state.namespace = namespace

  state.job_id = watch_adapter.watch(kind, namespace, {
    on_event = function(event_type, raw_resource)
      local resource = parser.parse_single_resource(raw_resource)
      callbacks.on_event(event_type, resource)
    end,
    on_error = function(error)
      callbacks.on_error(error)
    end,
    on_exit = function()
      state.job_id = nil
    end,
  })

  if state.job_id and callbacks.on_started then
    callbacks.on_started()
  end
end

---Stop watching
function M.stop()
  if state.job_id then
    local watch_adapter = require("k8s.infra.kubectl.watch_adapter")
    watch_adapter.stop(state.job_id)
    state.job_id = nil
  end
  state.kind = nil
  state.namespace = nil
end

---Check if watcher is running
---@return boolean
function M.is_running()
  return state.job_id ~= nil
end

---Get current watch state
---@return WatcherState
function M.get_state()
  return {
    job_id = state.job_id,
    kind = state.kind,
    namespace = state.namespace,
  }
end

---Restart watch with same kind/namespace
---@param callbacks WatcherCallbacks
function M.restart(callbacks)
  if state.kind and state.namespace then
    M.start(state.kind, state.namespace, callbacks)
  end
end

return M
