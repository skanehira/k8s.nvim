--- watcher.lua - Watcher ライフサイクル管理

local M = {}

local state = require("k8s.state")
local watch_adapter = require("k8s.adapters.kubectl.watch")
local parser = require("k8s.adapters.kubectl.parser")

-- Debug logging (set to true to enable)
local DEBUG = false

local function debug_log(msg)
  if DEBUG then
    vim.schedule(function()
      vim.notify("[k8s.watcher] " .. msg, vim.log.levels.DEBUG)
    end)
  end
end

---Start watching resources for the current view
---@param kind string Resource kind (e.g., "Pod", "Deployment")
---@param namespace string Namespace
---@param callbacks? { on_started?: function }
---@return number|nil job_id
function M.start(kind, namespace, callbacks)
  callbacks = callbacks or {}

  debug_log("Starting watch for " .. kind .. " in " .. namespace)

  local job_id = watch_adapter.watch(string.lower(kind) .. "s", namespace, {
    on_event = function(event_type, raw_resource)
      debug_log("Received event: " .. event_type .. " for " .. (raw_resource.kind or "unknown"))

      -- Get current view and verify it matches
      local current_view = state.get_current_view()
      if not current_view then
        debug_log("No current view, ignoring event")
        return
      end

      -- Check if this event is for the current view's kind
      local view_kind = state.get_kind_from_view_type(current_view.type)
      debug_log("View type: " .. current_view.type .. ", view_kind: " .. tostring(view_kind) .. ", resource.kind: " .. tostring(raw_resource.kind))
      if raw_resource.kind ~= view_kind then
        debug_log("Kind mismatch, ignoring event")
        return
      end

      -- Parse the resource
      local resource = parser.parse_single_resource(raw_resource)
      debug_log("Parsed resource: " .. resource.name .. " (" .. resource.status .. ")")

      -- Update state based on event type
      if event_type == "ADDED" or event_type == "MODIFIED" then
        state.add_resource(resource)
        debug_log("Added/modified resource, total: " .. #(state.get_current_view().resources or {}))
      elseif event_type == "DELETED" then
        state.remove_resource(resource.name, resource.namespace)
        debug_log("Removed resource")
      end
    end,
    on_error = function(error_msg)
      vim.notify("Watch error: " .. error_msg, vim.log.levels.ERROR)
    end,
    on_exit = function()
      -- Clear watcher job_id from state
      local current_view = state.get_current_view()
      if current_view and current_view.watcher_job_id then
        state.set_watcher_job_id(nil)
      end
    end,
    on_started = callbacks.on_started,
  })

  if job_id then
    state.set_watcher_job_id(job_id)
  end

  return job_id
end

---Stop the current watcher
function M.stop()
  local current_view = state.get_current_view()
  if current_view and current_view.watcher_job_id then
    watch_adapter.stop(current_view.watcher_job_id)
    state.set_watcher_job_id(nil)
  end
end

---Restart watcher for the current view
---@param callbacks? { on_started?: function }
function M.restart(callbacks)
  M.stop()

  local current_view = state.get_current_view()
  if not current_view then
    return
  end

  local kind = state.get_kind_from_view_type(current_view.type)
  if not kind then
    return
  end

  local namespace = state.get_namespace()
  M.start(kind, namespace, callbacks)
end

return M
