--- state/view.lua - View State management

local M = {}

-- =============================================================================
-- View Type Definitions
-- =============================================================================

---@alias ViewType
---| "pod_list"
---| "deployment_list"
---| "service_list"
---| "configmap_list"
---| "secret_list"
---| "node_list"
---| "namespace_list"
---| "port_forward_list"
---| "pod_describe"
---| "deployment_describe"
---| "service_describe"
---| "configmap_describe"
---| "secret_describe"
---| "node_describe"
---| "namespace_describe"
---| "help"

-- Mapping from view type to kind
local type_to_kind = {
  pod_list = "Pod",
  deployment_list = "Deployment",
  service_list = "Service",
  configmap_list = "ConfigMap",
  secret_list = "Secret",
  node_list = "Node",
  namespace_list = "Namespace",
  pod_describe = "Pod",
  deployment_describe = "Deployment",
  service_describe = "Service",
  configmap_describe = "ConfigMap",
  secret_describe = "Secret",
  node_describe = "Node",
  namespace_describe = "Namespace",
}

-- List view types
local list_types = {
  pod_list = true,
  deployment_list = true,
  service_list = true,
  configmap_list = true,
  secret_list = true,
  node_list = true,
  namespace_list = true,
  port_forward_list = true,
}

-- Describe view types
local describe_types = {
  pod_describe = true,
  deployment_describe = true,
  service_describe = true,
  configmap_describe = true,
  secret_describe = true,
  node_describe = true,
  namespace_describe = true,
}

-- =============================================================================
-- View Type Utilities
-- =============================================================================

---Get kind from view type
---@param view_type ViewType
---@return string|nil
function M.get_kind_from_type(view_type)
  return type_to_kind[view_type]
end

---Check if view type is a list view
---@param view_type ViewType
---@return boolean
function M.is_list_type(view_type)
  return list_types[view_type] == true
end

---Check if view type is a describe view
---@param view_type ViewType
---@return boolean
function M.is_describe_type(view_type)
  return describe_types[view_type] == true
end

---Get list view type from kind
---@param kind K8sResourceKind e.g., "Pod"
---@return ViewType
function M.get_list_type_from_kind(kind)
  return string.lower(kind) .. "_list"
end

---Get describe view type from kind
---@param kind K8sResourceKind e.g., "Pod"
---@return ViewType
function M.get_describe_type_from_kind(kind)
  return string.lower(kind) .. "_describe"
end

-- =============================================================================
-- View State Factory
-- =============================================================================

---@class ViewState
---@field type ViewType
---@field window table|nil
---@field on_mounted function|nil
---@field on_unmounted function|nil
---@field render function|nil
---@field resources table[]|nil List view only
---@field filter string|nil List view only
---@field cursor number|nil List view only
---@field watcher_job_id number|nil List view only
---@field resource table|nil Describe view only
---@field describe_output string|nil Describe view only
---@field mask_secrets boolean|nil secret_describe only
---@field secret_data table<string, string>|nil secret_describe only
---@field parent_cursor number|nil Cursor position in parent view
---@field help_content string[]|nil help view only
---@field parent_type string|nil help view only

---Create a new list view state
---@param view_type ViewType
---@param opts? { window?: table, on_mounted?: function, on_unmounted?: function, render?: function, parent_cursor?: number }
---@return ViewState
function M.create_list_state(view_type, opts)
  opts = opts or {}
  return {
    type = view_type,
    window = opts.window,
    on_mounted = opts.on_mounted,
    on_unmounted = opts.on_unmounted,
    render = opts.render,
    resources = {},
    filter = nil,
    cursor = 1,
    watcher_job_id = nil,
    parent_cursor = opts.parent_cursor,
  }
end

---Create a new describe view state
---@param view_type ViewType
---@param resource table Target resource
---@param opts? { window?: table, on_mounted?: function, on_unmounted?: function, render?: function, parent_cursor?: number }
---@return ViewState
function M.create_describe_state(view_type, resource, opts)
  opts = opts or {}
  return {
    type = view_type,
    window = opts.window,
    on_mounted = opts.on_mounted,
    on_unmounted = opts.on_unmounted,
    render = opts.render,
    resource = resource,
    describe_output = nil,
    mask_secrets = true,
    parent_cursor = opts.parent_cursor,
  }
end

---Create a help view state
---@param opts? { window?: table, on_mounted?: function, on_unmounted?: function, render?: function, parent_cursor?: number }
---@return ViewState
function M.create_help_state(opts)
  opts = opts or {}
  return {
    type = "help",
    window = opts.window,
    on_mounted = opts.on_mounted,
    on_unmounted = opts.on_unmounted,
    render = opts.render,
    parent_cursor = opts.parent_cursor,
  }
end

-- =============================================================================
-- View State Updates (Immutable)
-- =============================================================================

---Find resource index by name and namespace
---@param resources table[]
---@param name string
---@param namespace string
---@return number|nil
local function find_resource_index(resources, name, namespace)
  for i, r in ipairs(resources) do
    if r.name == name and r.namespace == namespace then
      return i
    end
  end
  return nil
end

---Add resource to view (upsert)
---@param view ViewState
---@param resource table
---@return ViewState
function M.add_resource(view, resource)
  if not view.resources then
    return view
  end

  local new_resources = vim.list_extend({}, view.resources)
  local index = find_resource_index(new_resources, resource.name, resource.namespace)

  if index then
    new_resources[index] = resource
  else
    table.insert(new_resources, resource)
  end

  return vim.tbl_extend("force", view, { resources = new_resources })
end

---Update resource in view
---@param view ViewState
---@param resource table
---@return ViewState
function M.update_resource(view, resource)
  if not view.resources then
    return view
  end

  local new_resources = vim.list_extend({}, view.resources)
  local index = find_resource_index(new_resources, resource.name, resource.namespace)

  if index then
    new_resources[index] = resource
  end

  return vim.tbl_extend("force", view, { resources = new_resources })
end

---Remove resource from view
---@param view ViewState
---@param name string
---@param namespace string
---@return ViewState
function M.remove_resource(view, name, namespace)
  if not view.resources then
    return view
  end

  local new_resources = {}
  for _, r in ipairs(view.resources) do
    if not (r.name == name and r.namespace == namespace) then
      table.insert(new_resources, r)
    end
  end

  return vim.tbl_extend("force", view, { resources = new_resources })
end

---Clear resources in view
---@param view ViewState
---@return ViewState
function M.clear_resources(view)
  if not view.resources then
    return view
  end
  return vim.tbl_extend("force", view, { resources = {} })
end

---Set filter in view
---@param view ViewState
---@param filter string|nil
---@return ViewState
function M.set_filter(view, filter)
  return vim.tbl_extend("force", view, { filter = filter, cursor = 1 })
end

---Set cursor in view
---@param view ViewState
---@param cursor number
---@return ViewState
function M.set_cursor(view, cursor)
  return vim.tbl_extend("force", view, { cursor = cursor })
end

---Set mask_secrets in view
---@param view ViewState
---@param mask boolean
---@return ViewState
function M.set_mask_secrets(view, mask)
  return vim.tbl_extend("force", view, { mask_secrets = mask })
end

---Set describe output in view
---@param view ViewState
---@param output string
---@return ViewState
function M.set_describe_output(view, output)
  return vim.tbl_extend("force", view, { describe_output = output })
end

---Set watcher job id in view
---@param view ViewState
---@param job_id number|nil
---@return ViewState
function M.set_watcher_job_id(view, job_id)
  return vim.tbl_extend("force", view, { watcher_job_id = job_id })
end

-- =============================================================================
-- Global View Operations
-- =============================================================================

---Clear resources in all list views (called on namespace change)
function M.clear_all_resources()
  local global = require("k8s.state.global")
  global.update(function(state)
    local new_stack = {}
    for _, v in ipairs(state.view_stack) do
      if v.resources then
        table.insert(new_stack, vim.tbl_extend("force", v, { resources = {} }))
      else
        table.insert(new_stack, v)
      end
    end
    return vim.tbl_extend("force", state, { view_stack = new_stack })
  end)
end

-- =============================================================================
-- Filtered Resources
-- =============================================================================

---Get filtered resources from view
---@param view ViewState
---@return table[]
function M.get_filtered_resources(view)
  if not view.resources then
    return {}
  end

  local filter = view.filter
  if not filter or filter == "" then
    return view.resources
  end

  local lower_filter = filter:lower()
  local filtered = {}

  for _, resource in ipairs(view.resources) do
    local name = (resource.name or ""):lower()
    local namespace = (resource.namespace or ""):lower()

    if name:find(lower_filter, 1, true) or namespace:find(lower_filter, 1, true) then
      table.insert(filtered, resource)
    end
  end

  return filtered
end

---Get resource at cursor in view
---@param view ViewState
---@return table|nil
function M.get_resource_at_cursor(view)
  local filtered = M.get_filtered_resources(view)
  local cursor = view.cursor or 1

  if cursor < 1 or cursor > #filtered then
    return nil
  end

  return filtered[cursor]
end

return M
