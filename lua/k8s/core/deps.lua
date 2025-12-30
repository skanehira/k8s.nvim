--- deps.lua - 依存性コンテナ（テスタビリティ向上用）

local M = {}

-- Default module mappings
local defaults = {
  global_state = "k8s.core.global_state",
  app = "k8s.core.state",
  view_stack = "k8s.core.view_stack",
  window = "k8s.ui.nui.window",
  buffer = "k8s.ui.nui.buffer",
  adapter = "k8s.infra.kubectl.adapter",
  resource = "k8s.core.resource",
  connections = "k8s.core.connections",
}

-- Override storage
local overrides = {}

---Get a dependency (returns override if set, otherwise default)
---@param name string
---@return table
function M.get(name)
  if overrides[name] then
    return overrides[name]
  end

  local module_path = defaults[name]
  if module_path then
    return require(module_path)
  end

  error("Unknown dependency: " .. name)
end

---Set an override for a dependency
---@param name string
---@param module table
function M.set(name, module)
  overrides[name] = module
end

---Reset all overrides
function M.reset()
  overrides = {}
end

---Execute function with temporary mocks, restoring after
---@param mocks table<string, table>
---@param fn function
function M.with_mocks(mocks, fn)
  local saved = {}

  -- Save current overrides and apply mocks
  for name, mock in pairs(mocks) do
    saved[name] = overrides[name]
    overrides[name] = mock
  end

  -- Execute function with protected call
  local ok, err = pcall(fn)

  -- Restore saved overrides
  for name, _ in pairs(mocks) do
    overrides[name] = saved[name]
  end

  -- Re-throw error if any
  if not ok then
    error(err)
  end
end

---Create a mock global_state for testing
---@param initial? { app_state?: table, window?: table, config?: table, view_stack?: table }
---@return table
function M.create_mock_global_state(initial)
  initial = initial or {}

  local state = {
    app_state = initial.app_state,
    window = initial.window,
    config = initial.config,
    view_stack = initial.view_stack,
    pf_list_connections = initial.pf_list_connections,
    setup_done = initial.setup_done or false,
  }

  return {
    get_app_state = function()
      return state.app_state
    end,
    set_app_state = function(value)
      state.app_state = value
    end,
    get_window = function()
      return state.window
    end,
    set_window = function(value)
      state.window = value
    end,
    get_config = function()
      return state.config
    end,
    set_config = function(value)
      state.config = value
    end,
    get_view_stack = function()
      return state.view_stack
    end,
    set_view_stack = function(value)
      state.view_stack = value
    end,
    get_pf_list_connections = function()
      return state.pf_list_connections
    end,
    set_pf_list_connections = function(value)
      state.pf_list_connections = value
    end,
    is_setup_done = function()
      return state.setup_done
    end,
    set_setup_done = function()
      state.setup_done = true
    end,
    reset = function()
      state = {
        app_state = nil,
        window = nil,
        config = nil,
        view_stack = nil,
        pf_list_connections = nil,
        setup_done = false,
      }
    end,
    -- For testing: access internal state
    _state = state,
  }
end

---Create a mock adapter for testing
---@param responses? table<string, table>
---@return table
function M.create_mock_adapter(responses)
  responses = responses or {}

  local calls = {
    delete = {},
    scale = {},
    restart = {},
    describe = {},
    logs = {},
    exec = {},
    port_forward = {},
    get_resources = {},
    get_contexts = {},
    get_namespaces = {},
    use_context = {},
  }

  local function create_mock_method(method_name)
    return function(...)
      local args = { ... }
      local call_info = {}

      -- Extract common parameters based on method
      if method_name == "delete" or method_name == "restart" then
        call_info = { kind = args[1], name = args[2], namespace = args[3], callback = args[4] }
      elseif method_name == "scale" then
        call_info = { kind = args[1], name = args[2], namespace = args[3], replicas = args[4], callback = args[5] }
      elseif method_name == "describe" then
        call_info = { kind = args[1], name = args[2], namespace = args[3], callback = args[4] }
      elseif method_name == "get_resources" then
        call_info = { kind = args[1], namespace = args[2], callback = args[3] }
      else
        call_info = { args = args }
      end

      table.insert(calls[method_name], call_info)

      -- Call callback with response if provided
      local callback = call_info.callback or (type(args[#args]) == "function" and args[#args])
      if callback then
        local response = responses[method_name] or { ok = true }
        callback(response)
      end

      return responses[method_name] or { ok = true }
    end
  end

  return {
    delete = create_mock_method("delete"),
    scale = create_mock_method("scale"),
    restart = create_mock_method("restart"),
    describe = create_mock_method("describe"),
    logs = create_mock_method("logs"),
    exec = create_mock_method("exec"),
    port_forward = create_mock_method("port_forward"),
    get_resources = create_mock_method("get_resources"),
    get_contexts = create_mock_method("get_contexts"),
    get_namespaces = create_mock_method("get_namespaces"),
    use_context = create_mock_method("use_context"),
    _calls = calls,
  }
end

---Create a mock window module for testing
---@param initial? { cursor?: number }
---@return table
function M.create_mock_window(initial)
  initial = initial or {}

  local state = {
    cursor = initial.cursor or 1,
    mounted = true,
    lines = {},
  }

  return {
    get_cursor = function()
      return state.cursor
    end,
    set_cursor = function(_, row)
      state.cursor = row
    end,
    is_mounted = function()
      return state.mounted
    end,
    mount = function() end,
    unmount = function()
      state.mounted = false
    end,
    show = function() end,
    hide = function() end,
    get_content_bufnr = function()
      return 1
    end,
    get_header_bufnr = function()
      return 2
    end,
    get_footer_bufnr = function()
      return 3
    end,
    get_table_header_bufnr = function()
      return 4
    end,
    set_lines = function(bufnr, lines)
      state.lines[bufnr] = lines
    end,
    create_list_view = function()
      return {}
    end,
    create_detail_view = function()
      return {}
    end,
    _state = state,
  }
end

return M
