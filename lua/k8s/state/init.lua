--- state/init.lua - State API
--- Observer pattern with single listener for state changes

local global = require("k8s.state.global")
local view = require("k8s.state.view")

local M = {}

-- Single listener for state changes
local listener = nil

-- =============================================================================
-- Observer Pattern
-- =============================================================================

---Subscribe to state changes
---@param fn function Listener function called on state change
function M.subscribe(fn)
  listener = fn
end

---Unsubscribe from state changes
function M.unsubscribe()
  listener = nil
end

---Notify listener of state change
function M.notify()
  if listener then
    listener()
  end
end

-- =============================================================================
-- Global State API
-- =============================================================================

---Get current context
---@return string|nil
function M.get_context()
  return global.get().current_context
end

---Set current context
---@param context string
function M.set_context(context)
  global.update(function(state)
    return vim.tbl_extend("force", state, { current_context = context })
  end)
  M.notify()
end

---Get current namespace
---@return string
function M.get_namespace()
  return global.get().current_namespace
end

---Set current namespace (clears all view resources)
---@param namespace string
function M.set_namespace(namespace)
  global.update(function(state)
    return vim.tbl_extend("force", state, { current_namespace = namespace })
  end)
  -- Clear resources in all list views
  view.clear_all_resources()
  M.notify()
end

---Get config
---@return table|nil
function M.get_config()
  return global.get().config
end

---Set config
---@param config table
function M.set_config(config)
  global.update(function(state)
    return vim.tbl_extend("force", state, { config = config })
  end)
end

---Check if setup is done
---@return boolean
function M.is_setup_done()
  return global.get().setup_done
end

---Mark setup as done
function M.set_setup_done()
  global.update(function(state)
    return vim.tbl_extend("force", state, { setup_done = true })
  end)
end

---Get current window
---@return table|nil
function M.get_window()
  return global.get().window
end

---Set current window
---@param window table|nil
function M.set_window(window)
  global.update(function(state)
    local new_state = vim.tbl_extend("force", state, {})
    new_state.window = window
    return new_state
  end)
end

-- =============================================================================
-- View Stack API
-- =============================================================================

---Get view stack
---@return table[]
function M.get_view_stack()
  return global.get().view_stack
end

---Get current view (top of stack)
---@return table|nil
function M.get_current_view()
  local stack = global.get().view_stack
  if #stack == 0 then
    return nil
  end
  return stack[#stack]
end

---Push view to stack
---@param view_state table
function M.push_view(view_state)
  global.update(function(state)
    local new_stack = vim.list_extend({}, state.view_stack)
    table.insert(new_stack, view_state)
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
end

---Pop view from stack
---@return table|nil Popped view
function M.pop_view()
  local popped = nil
  global.update(function(state)
    if #state.view_stack == 0 then
      return state
    end
    local new_stack = vim.list_extend({}, state.view_stack)
    popped = table.remove(new_stack)
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
  return popped
end

---Check if can pop (more than 1 view in stack)
---@return boolean
function M.can_pop_view()
  return #global.get().view_stack > 1
end

---Clear view stack
function M.clear_view_stack()
  global.update(function(state)
    return vim.tbl_extend("force", state, { view_stack = {} })
  end)
end

-- =============================================================================
-- Current View State API
-- =============================================================================

---Update current view state
---@param updater function(view) -> view
function M.update_view(updater)
  global.update(function(state)
    if #state.view_stack == 0 then
      return state
    end
    local new_stack = vim.list_extend({}, state.view_stack)
    local current = new_stack[#new_stack]
    new_stack[#new_stack] = updater(current)
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
  M.notify()
end

---Add resource to current view (upsert)
---@param resource table
function M.add_resource(resource)
  M.update_view(function(v)
    return view.add_resource(v, resource)
  end)
end

---Update resource in current view
---@param resource table
function M.update_resource(resource)
  M.update_view(function(v)
    return view.update_resource(v, resource)
  end)
end

---Remove resource from current view
---@param name string
---@param namespace string
function M.remove_resource(name, namespace)
  M.update_view(function(v)
    return view.remove_resource(v, name, namespace)
  end)
end

---Clear resources in current view
function M.clear_resources()
  M.update_view(function(v)
    return view.clear_resources(v)
  end)
end

---Set filter in current view
---@param filter string|nil
function M.set_filter(filter)
  M.update_view(function(v)
    return view.set_filter(v, filter)
  end)
end

---Set cursor in current view
---@param cursor number
function M.set_cursor(cursor)
  M.update_view(function(v)
    return view.set_cursor(v, cursor)
  end)
end

---Set mask_secrets in current view
---@param mask boolean
function M.set_mask_secrets(mask)
  M.update_view(function(v)
    return view.set_mask_secrets(v, mask)
  end)
end

---Set view type in current view
---@param view_type string
function M.set_view_type(view_type)
  global.update(function(state)
    if #state.view_stack == 0 then
      return state
    end
    local new_stack = vim.list_extend({}, state.view_stack)
    local current = new_stack[#new_stack]
    new_stack[#new_stack] = vim.tbl_extend("force", current, { type = view_type })
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
end

---Set window in current view (for view stack management)
---@param window table|nil
function M.set_current_view_window(window)
  global.update(function(state)
    if #state.view_stack == 0 then
      return state
    end
    local new_stack = vim.list_extend({}, state.view_stack)
    local current = new_stack[#new_stack]
    new_stack[#new_stack] = vim.tbl_extend("force", current, { window = window })
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
end

---Save current view state (cursor and window) without triggering notify
---@param cursor number
---@param window table|nil
function M.save_current_view_state(cursor, window)
  global.update(function(state)
    if #state.view_stack == 0 then
      return state
    end
    local new_stack = vim.list_extend({}, state.view_stack)
    local current = new_stack[#new_stack]
    new_stack[#new_stack] = vim.tbl_extend("force", current, {
      cursor = cursor,
      window = window,
    })
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
  -- Note: Does NOT call notify() to avoid triggering render during view transition
end

---Set watcher job_id in current view
---@param job_id number
function M.set_watcher_job_id(job_id)
  global.update(function(state)
    if #state.view_stack == 0 then
      return state
    end
    local new_stack = vim.list_extend({}, state.view_stack)
    local current = new_stack[#new_stack]
    current.watcher_job_id = job_id
    new_stack[#new_stack] = current
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
end

-- =============================================================================
-- Utility
-- =============================================================================

---Get kind from view type
---@param view_type string e.g., "pod_list", "deployment_describe"
---@return string|nil kind e.g., "Pod", "Deployment"
function M.get_kind_from_view_type(view_type)
  return view.get_kind_from_type(view_type)
end

---Check if view type is a list view
---@param view_type string
---@return boolean
function M.is_list_view(view_type)
  return view.is_list_type(view_type)
end

---Check if view type is a describe view
---@param view_type string
---@return boolean
function M.is_describe_view(view_type)
  return view.is_describe_type(view_type)
end

---Reset all state (for testing)
function M.reset()
  global.reset()
  listener = nil
end

return M
