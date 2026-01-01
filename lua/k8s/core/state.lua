--- state.lua - アプリケーション状態管理

local M = {}

---Create initial app state
---@param opts? { kind?: string, namespace?: string }
---@return table state
function M.create_state(opts)
  opts = opts or {}
  return {
    running = false,
    current_kind = opts.kind,
    current_namespace = opts.namespace,
    current_context = nil,
    resources = {},
    filter = nil,
    cursor = 1,
    mask_secrets = true, -- Default: mask secrets
  }
end

---Set running state (immutable)
---@param state table
---@param running boolean
---@return table new_state
function M.set_running(state, running)
  local new_state = M._copy_state(state)
  new_state.running = running
  return new_state
end

---Set current kind (immutable)
---@param state table
---@param kind string
---@return table new_state
function M.set_kind(state, kind)
  local new_state = M._copy_state(state)
  new_state.current_kind = kind
  new_state.resources = {} -- Clear resources on kind change
  new_state.cursor = 1
  return new_state
end

---Set current namespace (immutable)
---@param state table
---@param namespace string
---@return table new_state
function M.set_namespace(state, namespace)
  local new_state = M._copy_state(state)
  new_state.current_namespace = namespace
  new_state.resources = {} -- Clear resources on namespace change
  new_state.cursor = 1
  return new_state
end

---Set resources (immutable)
---@param state table
---@param resources table[]
---@return table new_state
function M.set_resources(state, resources)
  local new_state = M._copy_state(state)
  new_state.resources = resources
  return new_state
end

---Set filter (immutable)
---@param state table
---@param filter string|nil
---@return table new_state
function M.set_filter(state, filter)
  local new_state = M._copy_state(state)
  new_state.filter = filter
  new_state.cursor = 1
  return new_state
end

---Set cursor position (immutable)
---@param state table
---@param cursor number
---@return table new_state
function M.set_cursor(state, cursor)
  local new_state = M._copy_state(state)
  new_state.cursor = cursor
  return new_state
end

---Get filtered resources
---@param state table
---@return table[]
function M.get_filtered_resources(state)
  local resources = state.resources or {}
  local filter = state.filter

  if not filter or filter == "" then
    return resources
  end

  local lower_filter = filter:lower()
  local filtered = {}

  for _, resource in ipairs(resources) do
    local name = (resource.name or ""):lower()
    local namespace = (resource.namespace or ""):lower()

    if name:find(lower_filter, 1, true) or namespace:find(lower_filter, 1, true) then
      table.insert(filtered, resource)
    end
  end

  return filtered
end

---Get resource at current cursor
---@param state table
---@return table|nil
function M.get_current_resource(state)
  local filtered = M.get_filtered_resources(state)
  local cursor = state.cursor or 1

  if cursor < 1 or cursor > #filtered then
    return nil
  end

  return filtered[cursor]
end

---Set mask_secrets (immutable)
---@param state table
---@param mask boolean
---@return table new_state
function M.set_mask_secrets(state, mask)
  local new_state = M._copy_state(state)
  new_state.mask_secrets = mask
  return new_state
end

---Copy state helper
---@param state table
---@return table
function M._copy_state(state)
  return {
    running = state.running,
    current_kind = state.current_kind,
    current_namespace = state.current_namespace,
    current_context = state.current_context,
    resources = state.resources,
    filter = state.filter,
    cursor = state.cursor,
    mask_secrets = state.mask_secrets,
  }
end

-- =============================================================================
-- Standalone resource operations
-- =============================================================================

---Filter resources by name or namespace
---@param resources table[]
---@param filter_text string
---@return table[]
function M.filter_resources(resources, filter_text)
  if filter_text == "" then
    return resources
  end

  local pattern = filter_text:lower()
  local result = {}

  for _, resource in ipairs(resources) do
    local name_match = resource.name and resource.name:lower():find(pattern, 1, true)
    local ns_match = resource.namespace and resource.namespace:lower():find(pattern, 1, true)
    if name_match or ns_match then
      table.insert(result, resource)
    end
  end

  return result
end

---Sort resources by name (alphabetically, case-insensitive)
---@param resources table[]
---@return table[]
function M.sort_resources(resources)
  local sorted = {}
  for i, r in ipairs(resources) do
    sorted[i] = r
  end

  table.sort(sorted, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return sorted
end

return M
