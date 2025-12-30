--- init.lua - k8s.nvim メインモジュール

local M = {}

-- Module state
local state = {
  setup_done = false,
  config = nil,
  window = nil,
  app_state = nil,
  timer = nil, -- vim.uv timer handle
  view_stack = nil,
  connections = nil,
}

-- Command to kind mapping
local command_to_kind = {
  pods = "Pod",
  deployments = "Deployment",
  services = "Service",
  configmaps = "ConfigMap",
  secrets = "Secret",
  nodes = "Node",
  namespaces = "Namespace",
  portforwards = "PortForward",
}

---Get current state
---@return table
function M.get_state()
  return {
    setup_done = state.setup_done,
    config = state.config,
  }
end

---Check if setup is done
---@return boolean
function M.is_setup_done()
  return state.setup_done
end

---Create highlight definitions
---@return table
function M.create_highlights()
  return {
    K8sStatusRunning = { fg = "#50fa7b" }, -- Green
    K8sStatusPending = { fg = "#f1fa8c" }, -- Yellow
    K8sStatusError = { fg = "#ff5555" }, -- Red
    K8sHeader = { fg = "#8be9fd", bold = true }, -- Cyan
    K8sFooter = { fg = "#6272a4" }, -- Comment gray
    K8sTableHeader = { fg = "#bd93f9", bold = true }, -- Purple
    K8sNormal = { bg = "NONE" }, -- Transparent background
    K8sCursorLine = { bg = "#44475a" }, -- Subtle cursor line
  }
end

---Get default resource kind
---@return string
function M.get_default_kind()
  return "Pod"
end

---Get resource kind from command
---@param cmd string
---@return string|nil
function M.get_resource_kind_from_command(cmd)
  return command_to_kind[cmd]
end

-- Keymap definitions
local keymap_definitions = {
  describe = { key = "d", action = "describe", desc = "Describe resource" },
  delete = { key = "D", action = "delete", desc = "Delete resource" },
  logs = { key = "l", action = "logs", desc = "View logs" },
  exec = { key = "e", action = "exec", desc = "Execute shell" },
  scale = { key = "s", action = "scale", desc = "Scale resource" },
  restart = { key = "X", action = "restart", desc = "Restart resource" },
  port_forward = { key = "p", action = "port_forward", desc = "Port forward" },
  port_forward_list = { key = "F", action = "port_forward_list", desc = "Port forwards list" },
  filter = { key = "/", action = "filter", desc = "Filter" },
  refresh = { key = "r", action = "refresh", desc = "Refresh" },
  resource_menu = { key = "R", action = "resource_menu", desc = "Resources" },
  context_menu = { key = "C", action = "context_menu", desc = "Context" },
  namespace_menu = { key = "N", action = "namespace_menu", desc = "Namespace" },
  toggle_secret = { key = "S", action = "toggle_secret", desc = "Toggle secret" },
  logs_previous = { key = "P", action = "logs_previous", desc = "Previous logs" },
  help = { key = "?", action = "help", desc = "Help" },
  quit = { key = "q", action = "quit", desc = "Quit" },
  back = { key = "<C-h>", action = "back", desc = "Back" },
  select = { key = "<CR>", action = "select", desc = "Select" },
}

-- Footer keymaps for each view type
local footer_keymaps = {
  list = {
    { key = "d", action = "describe" },
    { key = "l", action = "logs" },
    { key = "D", action = "delete" },
    { key = "/", action = "filter" },
    { key = "r", action = "refresh" },
    { key = "?", action = "help" },
    { key = "q", action = "quit" },
  },
  describe = {
    { key = "l", action = "logs" },
    { key = "e", action = "exec" },
    { key = "D", action = "delete" },
    { key = "<C-h>", action = "back" },
    { key = "q", action = "quit" },
  },
  port_forward_list = {
    { key = "D", action = "delete" },
    { key = "<C-h>", action = "back" },
    { key = "q", action = "quit" },
  },
  help = {
    { key = "<C-h>", action = "back" },
    { key = "q", action = "quit" },
  },
}

---Get keymap definitions
---@return table
function M.get_keymap_definitions()
  return keymap_definitions
end

-- Actions allowed for each view type
local view_allowed_actions = {
  list = {
    describe = true,
    select = true,
    delete = true,
    logs = true,
    logs_previous = true,
    exec = true,
    scale = true,
    restart = true,
    port_forward = true,
    port_forward_list = true,
    filter = true,
    refresh = true,
    resource_menu = true,
    context_menu = true,
    namespace_menu = true,
    toggle_secret = true,
    help = true,
    quit = true,
    back = true,
  },
  describe = {
    back = true,
    logs = true,
    exec = true,
    delete = true,
    quit = true,
    help = true,
  },
  port_forward_list = {
    back = true,
    stop = true, -- D key in port_forward_list stops the connection
    quit = true,
    help = true,
  },
  help = {
    back = true,
    quit = true,
  },
}

---Get current view type from view stack
---@return string|nil
function M._get_current_view_type()
  local view_stack = require("k8s.app.view_stack")
  if not state.view_stack then
    return nil
  end
  local current = view_stack.current(state.view_stack)
  return current and current.type or nil
end

---Check if an action is allowed for the current view
---@param action string
---@return boolean
function M._is_action_allowed(action)
  local view_type = M._get_current_view_type()
  if not view_type then
    return false
  end
  local allowed = view_allowed_actions[view_type]
  return allowed and allowed[action] == true
end

-- Map action names to resource capability names
local action_to_capability = {
  logs = "logs",
  logs_previous = "logs",
  exec = "exec",
  scale = "scale",
  restart = "restart",
  port_forward = "port_forward",
}

---Check if current resource supports the given action
---@param action string
---@return boolean
function M._is_resource_capability_allowed(action)
  local capability = action_to_capability[action]
  if not capability then
    -- Action doesn't require capability check
    return true
  end

  local resource = M._get_current_resource()
  if not resource then
    return false
  end

  local resource_mod = require("k8s.domain.resources.resource")
  local caps = resource_mod.capabilities(resource.kind)
  return caps[capability] == true
end

---Get footer keymaps for a specific view, filtered by resource capability
---@param view_type string
---@param kind? string Resource kind for capability filtering
---@return table[]
function M.get_footer_keymaps(view_type, kind)
  local keymaps = footer_keymaps[view_type] or footer_keymaps.list

  -- If no kind specified, return all keymaps
  if not kind then
    return keymaps
  end

  -- Filter keymaps based on resource capabilities
  local resource_mod = require("k8s.domain.resources.resource")
  local caps = resource_mod.capabilities(kind)

  local filtered = {}
  for _, km in ipairs(keymaps) do
    local capability = action_to_capability[km.action]
    -- Include keymap if action doesn't require capability OR resource has the capability
    if not capability or caps[capability] == true then
      table.insert(filtered, km)
    end
  end

  return filtered
end

---Parse command arguments
---@param args string[]
---@return string command
---@return table|nil parsed_args
function M.parse_command_args(args)
  if #args == 0 then
    return "toggle", nil
  end

  local cmd = args[1]:lower()

  if cmd == "open" then
    return "open", nil
  elseif cmd == "close" then
    return "close", nil
  elseif cmd == "context" then
    return "context", { name = args[2] }
  elseif cmd == "namespace" then
    return "namespace", { name = args[2] }
  elseif cmd == "portforwards" then
    return "portforwards", nil
  else
    local kind = M.get_resource_kind_from_command(cmd)
    if kind then
      return "open_resource", { kind = kind }
    end
  end

  return "toggle", nil
end

-- =============================================================================
-- Public API
-- =============================================================================

---Setup k8s.nvim
---@param user_config? table
function M.setup(user_config)
  if state.setup_done then
    return
  end

  local config = require("k8s.config")
  state.config = config.merge(user_config)

  -- Validate config
  local valid, err = config.validate(state.config)
  if not valid then
    vim.notify("k8s.nvim: Invalid config: " .. err, vim.log.levels.ERROR)
    return
  end

  -- Setup highlight groups
  local highlights = M.create_highlights()
  for name, hl in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, hl)
  end

  -- Setup VimLeavePre autocmd to stop all port forwards
  local autocmd = require("k8s.autocmd")
  local group = vim.api.nvim_create_augroup(autocmd.get_group_name(), { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    pattern = "*",
    desc = autocmd.format_autocmd_desc("cleanup all port forwards"),
    callback = function()
      M._stop_all_port_forwards()
    end,
  })

  state.setup_done = true
end

---Stop all active port forwards
function M._stop_all_port_forwards()
  local connections = require("k8s.domain.state.connections")

  local all_connections = connections.get_all()
  for _, conn in ipairs(all_connections) do
    -- Stop the job
    pcall(vim.fn.jobstop, conn.job_id)
  end

  -- Clear connections
  connections.clear()
end

---Open k8s.nvim UI
---@param opts? { kind?: string }
function M.open(opts)
  opts = opts or {}

  -- Ensure setup was called
  if not state.setup_done then
    M.setup()
  end

  -- Check kubectl availability
  local health = require("k8s.api.health")
  if not health.check_kubectl() then
    vim.notify("k8s.nvim: kubectl not found. Please install kubectl first.", vim.log.levels.ERROR)
    return
  end

  -- Don't open if already open
  if state.window then
    local window = require("k8s.ui.nui.window")
    if window.is_mounted(state.window) then
      return
    end
  end

  local window = require("k8s.ui.nui.window")
  local app = require("k8s.app.app")
  local buffer = require("k8s.ui.nui.buffer")

  -- Create window
  state.window = window.create({
    transparent = state.config.transparent,
  })

  -- Create app state
  local kind = opts.kind or state.config.default_kind or "Pod"
  local namespace = state.config.default_namespace or "default"
  state.app_state = app.create_state({ kind = kind, namespace = namespace })

  -- Mount window
  window.mount(state.window)

  -- Render initial header
  local header_bufnr = window.get_header_bufnr(state.window)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = "loading...",
      namespace = namespace,
      view = kind .. "s",
      loading = true,
    })
    window.set_lines(header_bufnr, { header_content })
  end

  -- Render footer with keymaps
  M._render_footer("list", kind)

  -- Setup keymaps
  M._setup_keymaps()

  -- Initialize view stack with list view
  local view_stack = require("k8s.app.view_stack")
  state.view_stack = view_stack.push({}, { type = "list", kind = kind })

  -- Fetch resources
  M._fetch_and_render(kind, namespace)

  -- Start auto-refresh timer
  M._start_auto_refresh()
end

---Close k8s.nvim UI
function M.close()
  -- Stop auto-refresh timer
  M._stop_auto_refresh()

  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  window.unmount(state.window)
  state.window = nil
  state.app_state = nil
  state.view_stack = nil
end

---Toggle k8s.nvim UI
function M.toggle()
  if state.window then
    local window = require("k8s.ui.nui.window")
    if window.is_mounted(state.window) then
      M.close()
      return
    end
  end
  M.open()
end

---Switch to a specific context
---@param context_name string|nil Context name (if nil, shows menu)
function M.switch_context(context_name)
  if not context_name then
    -- If UI is open, use the menu handler
    if state.window then
      M._handle_context_menu()
    else
      vim.notify("Context name required. Usage: :K8s context <name>", vim.log.levels.WARN)
    end
    return
  end

  local adapter = require("k8s.infra.kubectl.adapter")
  adapter.use_context(context_name, function(result)
    vim.schedule(function()
      if result.ok then
        local notify = require("k8s.api.notify")
        vim.notify(notify.format_context_switch_message(context_name), vim.log.levels.INFO)
        -- Refresh if UI is open
        if state.window and state.app_state then
          M._handle_refresh()
        end
      else
        vim.notify("Failed to switch context: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  end)
end

---Switch to a specific namespace
---@param namespace_name string|nil Namespace name (if nil, shows menu)
function M.switch_namespace(namespace_name)
  if not namespace_name then
    -- If UI is open, use the menu handler
    if state.window then
      M._handle_namespace_menu()
    else
      vim.notify("Namespace name required. Usage: :K8s namespace <name>", vim.log.levels.WARN)
    end
    return
  end

  local app = require("k8s.app.app")
  local namespace = namespace_name == "all" and "" or namespace_name

  if state.app_state then
    state.app_state = app.set_namespace(state.app_state, namespace)
    local notify = require("k8s.api.notify")
    vim.notify(notify.format_namespace_switch_message(namespace_name), vim.log.levels.INFO)
    M._fetch_and_render(state.app_state.current_kind, namespace)
  else
    vim.notify("Namespace set to: " .. namespace_name, vim.log.levels.INFO)
  end
end

---Show port forwards list
function M.show_port_forwards()
  -- Ensure UI is open
  if not state.window then
    M.open()
    -- Wait for window to be ready, then show port forwards
    vim.schedule(function()
      M._handle_port_forward_list()
    end)
  else
    M._handle_port_forward_list()
  end
end

---Start auto-refresh timer
function M._start_auto_refresh()
  -- Don't start if already running
  if state.timer then
    return
  end

  local interval = state.config and state.config.refresh_interval or 5000

  -- Use vim.uv (libuv) for timer
  local timer = vim.uv.new_timer()
  if not timer then
    return
  end

  timer:start(
    interval,
    interval,
    vim.schedule_wrap(function()
      -- Only refresh if we're in list view and window is mounted
      if not state.window then
        return
      end

      local window = require("k8s.ui.nui.window")
      if not window.is_mounted(state.window) then
        return
      end

      local view_stack = require("k8s.app.view_stack")
      local current = view_stack.current(state.view_stack)

      -- Only auto-refresh in list view
      if current and current.type == "list" then
        M._handle_refresh()
      end
    end)
  )

  state.timer = timer
end

---Stop auto-refresh timer
function M._stop_auto_refresh()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

---Render footer with keymaps
---@param view_type string
---@param kind? string Resource kind for capability filtering
function M._render_footer(view_type, kind)
  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")

  local footer_bufnr = window.get_footer_bufnr(state.window)
  if footer_bufnr then
    local keymaps = M.get_footer_keymaps(view_type, kind)
    local footer_content = buffer.create_footer_content(keymaps)
    window.set_lines(footer_bufnr, { footer_content })
  end
end

---Setup keymaps for the content buffer
function M._setup_keymaps()
  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  local keymaps = M.get_keymap_definitions()

  -- quit (always allowed)
  window.map_key(state.window, keymaps.quit.key, function()
    M.close()
  end, { desc = keymaps.quit.desc })

  -- back (always allowed)
  window.map_key(state.window, keymaps.back.key, function()
    M._handle_back()
  end, { desc = keymaps.back.desc })

  -- describe
  window.map_key(state.window, keymaps.describe.key, function()
    if M._is_action_allowed("describe") then
      M._handle_describe()
    end
  end, { desc = keymaps.describe.desc })

  -- select (Enter key)
  window.map_key(state.window, keymaps.select.key, function()
    if M._is_action_allowed("select") then
      M._handle_describe()
    end
  end, { desc = keymaps.select.desc })

  -- refresh
  window.map_key(state.window, keymaps.refresh.key, function()
    if M._is_action_allowed("refresh") then
      M._handle_refresh()
    end
  end, { desc = keymaps.refresh.desc })

  -- filter
  window.map_key(state.window, keymaps.filter.key, function()
    if M._is_action_allowed("filter") then
      M._handle_filter()
    end
  end, { desc = keymaps.filter.desc })

  -- delete (D key) - different behavior per view
  window.map_key(state.window, keymaps.delete.key, function()
    local view_type = M._get_current_view_type()
    if view_type == "port_forward_list" then
      if M._is_action_allowed("stop") then
        M._handle_stop_port_forward()
      end
    elseif M._is_action_allowed("delete") then
      M._handle_delete()
    end
  end, { desc = keymaps.delete.desc })

  -- logs
  window.map_key(state.window, keymaps.logs.key, function()
    if M._is_action_allowed("logs") and M._is_resource_capability_allowed("logs") then
      M._handle_logs()
    end
  end, { desc = keymaps.logs.desc })

  -- exec
  window.map_key(state.window, keymaps.exec.key, function()
    if M._is_action_allowed("exec") and M._is_resource_capability_allowed("exec") then
      M._handle_exec()
    end
  end, { desc = keymaps.exec.desc })

  -- scale
  window.map_key(state.window, keymaps.scale.key, function()
    if M._is_action_allowed("scale") and M._is_resource_capability_allowed("scale") then
      M._handle_scale()
    end
  end, { desc = keymaps.scale.desc })

  -- restart
  window.map_key(state.window, keymaps.restart.key, function()
    if M._is_action_allowed("restart") and M._is_resource_capability_allowed("restart") then
      M._handle_restart()
    end
  end, { desc = keymaps.restart.desc })

  -- port_forward
  window.map_key(state.window, keymaps.port_forward.key, function()
    if M._is_action_allowed("port_forward") and M._is_resource_capability_allowed("port_forward") then
      M._handle_port_forward()
    end
  end, { desc = keymaps.port_forward.desc })

  -- port_forward_list
  window.map_key(state.window, keymaps.port_forward_list.key, function()
    if M._is_action_allowed("port_forward_list") then
      M._handle_port_forward_list()
    end
  end, { desc = keymaps.port_forward_list.desc })

  -- resource_menu
  window.map_key(state.window, keymaps.resource_menu.key, function()
    if M._is_action_allowed("resource_menu") then
      M._handle_resource_menu()
    end
  end, { desc = keymaps.resource_menu.desc })

  -- context_menu
  window.map_key(state.window, keymaps.context_menu.key, function()
    if M._is_action_allowed("context_menu") then
      M._handle_context_menu()
    end
  end, { desc = keymaps.context_menu.desc })

  -- namespace_menu
  window.map_key(state.window, keymaps.namespace_menu.key, function()
    if M._is_action_allowed("namespace_menu") then
      M._handle_namespace_menu()
    end
  end, { desc = keymaps.namespace_menu.desc })

  -- logs_previous
  window.map_key(state.window, keymaps.logs_previous.key, function()
    if M._is_action_allowed("logs_previous") and M._is_resource_capability_allowed("logs_previous") then
      M._handle_logs_previous()
    end
  end, { desc = keymaps.logs_previous.desc })

  -- toggle_secret
  window.map_key(state.window, keymaps.toggle_secret.key, function()
    if M._is_action_allowed("toggle_secret") then
      M._handle_toggle_secret()
    end
  end, { desc = keymaps.toggle_secret.desc })

  -- help
  window.map_key(state.window, keymaps.help.key, function()
    if M._is_action_allowed("help") then
      M._handle_help()
    end
  end, { desc = keymaps.help.desc })
end

---Fetch resources and render
---@param kind string
---@param namespace string
---@param opts? { preserve_cursor?: boolean }
function M._fetch_and_render(kind, namespace, opts)
  opts = opts or {}
  local window = require("k8s.ui.nui.window")
  local app = require("k8s.app.app")
  local columns = require("k8s.ui.views.columns")
  local buffer = require("k8s.ui.nui.buffer")
  local adapter = require("k8s.infra.kubectl.adapter")
  local table_component = require("k8s.ui.components.table")

  -- Save current cursor position before refresh, or use restore_cursor if provided
  local saved_cursor_row = nil
  if opts.restore_cursor then
    saved_cursor_row = opts.restore_cursor
  elseif opts.preserve_cursor and state.window then
    saved_cursor_row = window.get_cursor(state.window)
  end

  -- Show loading indicator in header
  if state.window and window.is_mounted(state.window) then
    local header_bufnr = window.get_header_bufnr(state.window)
    if header_bufnr then
      local header_content = buffer.create_header_content({
        context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
        namespace = namespace,
        view = kind .. "s",
        loading = true,
      })
      window.set_lines(header_bufnr, { header_content })
    end
  end

  adapter.get_resources(kind, namespace, function(result)
    vim.schedule(function()
      if not state.window or not window.is_mounted(state.window) then
        return
      end

      -- Update header (remove loading)
      local header_bufnr = window.get_header_bufnr(state.window)
      if header_bufnr then
        local header_content = buffer.create_header_content({
          context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
          namespace = namespace,
          view = kind .. "s",
        })
        window.set_lines(header_bufnr, { header_content })
      end

      local content_bufnr = window.get_content_bufnr(state.window)
      if not content_bufnr then
        return
      end

      if not result.ok then
        local error_lines = vim.split("Error: " .. (result.error or "Unknown error"), "\n")
        window.set_lines(content_bufnr, error_lines)
        return
      end

      -- Update app state
      state.app_state = app.set_resources(state.app_state, result.data)

      -- Get columns for this kind
      local cols = columns.get_columns(kind)

      -- Get filtered resources (apply current filter)
      local filtered_resources = app.get_filtered_resources(state.app_state)

      -- Extract row data
      local rows = {}
      for _, resource in ipairs(filtered_resources) do
        table.insert(rows, columns.extract_row(resource))
      end

      -- Prepare table content
      local content = buffer.prepare_table_content(cols, rows)

      -- Set lines
      window.set_lines(content_bufnr, content.lines)

      -- Add highlights for status column
      local status_key = columns.get_status_column_key(kind)
      local status_col_idx = buffer.find_status_column_index(cols, status_key)

      if status_col_idx then
        local hl_range = buffer.get_highlight_range(content.widths, status_col_idx)

        for i, row in ipairs(rows) do
          local status = row[status_key]
          local hl_group = table_component.get_status_highlight(status)
          if hl_group then
            window.add_highlight(content_bufnr, hl_group, i, hl_range.start_col, hl_range.end_col)
          end
        end
      end

      -- Update footer with capability-filtered keymaps
      M._render_footer("list", kind)

      -- Restore cursor position or set to first data row
      if saved_cursor_row and #rows > 0 then
        -- Clamp cursor to valid range (row 2 to #rows + 1, accounting for header)
        local max_row = #rows + 1
        local target_row = math.min(saved_cursor_row, max_row)
        target_row = math.max(target_row, 2)
        window.set_cursor(state.window, target_row, 0)
      elseif #rows > 0 then
        window.set_cursor(state.window, 2, 0)
      end
    end)
  end)
end

---Render cached resources (no fetch)
---@param opts? { preserve_cursor?: boolean }
function M._render_cached_resources(opts)
  opts = opts or {}
  local window = require("k8s.ui.nui.window")
  local app = require("k8s.app.app")
  local columns = require("k8s.ui.views.columns")
  local buffer = require("k8s.ui.nui.buffer")
  local table_component = require("k8s.ui.components.table")

  if not state.window or not window.is_mounted(state.window) then
    return
  end

  if not state.app_state or not state.app_state.resources then
    return
  end

  local kind = state.app_state.current_kind

  -- Save current cursor position before refresh
  local saved_cursor_row = nil
  if opts.preserve_cursor then
    saved_cursor_row = window.get_cursor(state.window)
  end

  -- Skip header update on back - context/namespace hasn't changed and kubectl is slow

  local content_bufnr = window.get_content_bufnr(state.window)
  if not content_bufnr then
    return
  end

  -- Get columns for this kind
  local cols = columns.get_columns(kind)

  -- Extract row data from filtered resources
  local filtered = app.get_filtered_resources(state.app_state)
  local rows = {}
  for _, resource in ipairs(filtered) do
    table.insert(rows, columns.extract_row(resource))
  end

  -- Prepare table content
  local content = buffer.prepare_table_content(cols, rows)

  -- Set lines
  window.set_lines(content_bufnr, content.lines)

  -- Add highlights for status column
  local status_key = columns.get_status_column_key(kind)
  local status_col_idx = buffer.find_status_column_index(cols, status_key)

  if status_col_idx then
    local hl_range = buffer.get_highlight_range(content.widths, status_col_idx)

    for i, row in ipairs(rows) do
      local status = row[status_key]
      local hl_group = table_component.get_status_highlight(status)
      if hl_group then
        window.add_highlight(content_bufnr, hl_group, i, hl_range.start_col, hl_range.end_col)
      end
    end
  end

  -- Restore cursor position or set to first data row
  if saved_cursor_row and #rows > 0 then
    local max_row = #rows + 1
    local target_row = math.min(saved_cursor_row, max_row)
    target_row = math.max(target_row, 2)
    window.set_cursor(state.window, target_row, 0)
  elseif #rows > 0 then
    window.set_cursor(state.window, 2, 0)
  end
end

-- =============================================================================
-- Action Handlers
-- =============================================================================

---Get current resource at cursor position
---@return table|nil
function M._get_current_resource()
  if not state.app_state then
    return nil
  end

  local app = require("k8s.app.app")
  local window = require("k8s.ui.nui.window")

  -- Get cursor position (1-indexed, row 1 is header)
  local row = window.get_cursor(state.window)
  -- Subtract 1 for header row
  local cursor_idx = row - 1

  local filtered = app.get_filtered_resources(state.app_state)
  if cursor_idx < 1 or cursor_idx > #filtered then
    return nil
  end

  return filtered[cursor_idx]
end

---Handle back action
function M._handle_back()
  local view_stack = require("k8s.app.view_stack")
  local window = require("k8s.ui.nui.window")

  if not state.view_stack or not view_stack.can_pop(state.view_stack) then
    -- Do nothing if there's nothing to go back to
    return
  end

  -- pop returns (new_stack, popped_view)
  local new_stack, popped_view = view_stack.pop(state.view_stack)
  state.view_stack = new_stack

  -- Get cursor position to restore from popped view
  local restore_cursor = popped_view and popped_view.parent_cursor

  local current = view_stack.current(state.view_stack)

  if current then
    if current.type == "list" then
      local kind = current.kind or state.app_state.current_kind
      M._render_footer("list", kind)

      -- Restore the kind if different
      if current.kind and current.kind ~= state.app_state.current_kind then
        local app = require("k8s.app.app")
        state.app_state = app.set_kind(state.app_state, current.kind)
      end

      -- Always fetch fresh resources with cursor restore
      M._fetch_and_render(kind, state.app_state.current_namespace, {
        restore_cursor = restore_cursor,
      })
    elseif current.type == "describe" then
      -- Re-render describe view
      local kind = current.resource and current.resource.kind
      M._render_footer("describe", kind)
      -- Describe content should still be in buffer, just update footer
      -- Restore cursor if available
      if restore_cursor and state.window then
        window.set_cursor(state.window, restore_cursor, 0)
      end
    end
  end
end

---Handle describe action
function M._handle_describe()
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local window = require("k8s.ui.nui.window")
  local adapter = require("k8s.infra.kubectl.adapter")
  local view_stack = require("k8s.app.view_stack")

  -- Save current cursor position before pushing new view
  local cursor_row = 1
  if state.window then
    cursor_row = window.get_cursor(state.window)
  end

  -- Push describe view to stack with parent cursor
  if not state.view_stack then
    state.view_stack = {}
  end
  state.view_stack = view_stack.push(state.view_stack, {
    type = "describe",
    resource = resource,
    parent_cursor = cursor_row,
  })

  -- Update footer
  M._render_footer("describe", resource.kind)

  -- Fetch describe output
  adapter.describe(resource.kind, resource.name, resource.namespace, function(result)
    vim.schedule(function()
      if not state.window or not window.is_mounted(state.window) then
        return
      end

      local content_bufnr = window.get_content_bufnr(state.window)
      if not content_bufnr then
        return
      end

      if not result.ok then
        local error_lines = vim.split("Error: " .. (result.error or "Unknown error"), "\n")
        window.set_lines(content_bufnr, error_lines)
        return
      end

      -- Set lines
      local lines = vim.split(result.data, "\n")

      -- Apply secret mask if viewing a Secret
      if resource.kind == "Secret" and state.app_state and state.app_state.mask_secrets then
        local secret_mask = require("k8s.ui.components.secret_mask")
        lines = secret_mask.mask_describe_output(true, lines)
      end

      window.set_lines(content_bufnr, lines)

      -- Set filetype for syntax highlighting
      vim.api.nvim_buf_set_option(content_bufnr, "filetype", "yaml")

      -- Update header
      local header_bufnr = window.get_header_bufnr(state.window)
      if header_bufnr then
        local buffer = require("k8s.ui.nui.buffer")
        local header_content = buffer.create_header_content({
          context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
          namespace = resource.namespace,
          view = resource.kind .. ": " .. resource.name,
        })
        window.set_lines(header_bufnr, { header_content })
      end

      -- Set cursor to top
      window.set_cursor(state.window, 1, 0)
    end)
  end)
end

---Handle refresh action
function M._handle_refresh()
  if not state.app_state then
    return
  end

  M._fetch_and_render(state.app_state.current_kind, state.app_state.current_namespace, { preserve_cursor = true })
end

---Handle filter action
function M._handle_filter()
  local filter_actions = require("k8s.handlers.filter_actions")

  local prompt = filter_actions.format_filter_prompt()
  local current_filter = state.app_state and state.app_state.filter or ""

  vim.ui.input({ prompt = prompt, default = current_filter }, function(input)
    if input == nil then
      return -- Cancelled
    end

    local app = require("k8s.app.app")

    if input == "" then
      -- Clear filter
      state.app_state = app.set_filter(state.app_state, nil)
    else
      state.app_state = app.set_filter(state.app_state, input)
    end

    -- Re-render with filter applied
    M._render_filtered_resources()
  end)
end

---Render resources with current filter
function M._render_filtered_resources()
  if not state.window or not state.app_state then
    return
  end

  local window = require("k8s.ui.nui.window")
  local app = require("k8s.app.app")
  local columns = require("k8s.ui.views.columns")
  local buffer = require("k8s.ui.nui.buffer")
  local table_component = require("k8s.ui.components.table")

  local content_bufnr = window.get_content_bufnr(state.window)
  if not content_bufnr then
    return
  end

  -- Get filtered resources
  local resources = app.get_filtered_resources(state.app_state)
  local kind = state.app_state.current_kind

  -- Get columns
  local cols = columns.get_columns(kind)

  -- Extract row data
  local rows = {}
  for _, resource in ipairs(resources) do
    table.insert(rows, columns.extract_row(resource))
  end

  -- Prepare table content
  local content = buffer.prepare_table_content(cols, rows)

  -- Set lines
  window.set_lines(content_bufnr, content.lines)

  -- Add highlights
  local status_key = columns.get_status_column_key(kind)
  local status_col_idx = buffer.find_status_column_index(cols, status_key)

  if status_col_idx then
    local hl_range = buffer.get_highlight_range(content.widths, status_col_idx)

    for i, row in ipairs(rows) do
      local status = row[status_key]
      local hl_group = table_component.get_status_highlight(status)
      if hl_group then
        window.add_highlight(content_bufnr, hl_group, i, hl_range.start_col, hl_range.end_col)
      end
    end
  end

  -- Update header to show filter
  local header_bufnr = window.get_header_bufnr(state.window)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = state.app_state.current_namespace,
      view = kind .. "s",
      filter = state.app_state.filter,
    })
    window.set_lines(header_bufnr, { header_content })
  end

  -- Set cursor
  if #rows > 0 then
    window.set_cursor(state.window, 2, 0)
  end
end

---Handle delete action
function M._handle_delete()
  -- Check if we're in port_forward_list view
  local view_stack = require("k8s.app.view_stack")
  local current = view_stack.current(state.view_stack)
  if current and current.type == "port_forward_list" then
    M._handle_stop_port_forward()
    return
  end

  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local resource_actions = require("k8s.handlers.resource_actions")

  if not resource_actions.validate_delete_target(resource.kind) then
    vim.notify("Cannot delete " .. resource.kind, vim.log.levels.WARN)
    return
  end

  local action = resource_actions.create_delete_action(resource)
  local choice = vim.fn.confirm(action.confirm_message, "&Yes\n&No", 2)

  if choice ~= 1 then
    return
  end

  local adapter = require("k8s.infra.kubectl.adapter")

  adapter.delete(resource.kind, resource.name, resource.namespace, function(result)
    vim.schedule(function()
      if result.ok then
        vim.notify(
          resource_actions.format_action_result("delete", resource.kind, resource.name, true),
          vim.log.levels.INFO
        )
        M._handle_refresh()
      else
        vim.notify(
          resource_actions.format_action_result("delete", resource.kind, resource.name, false, result.error),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

---Handle logs action
function M._handle_logs()
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local pod_actions = require("k8s.handlers.pod_actions")

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Logs are only available for Pods", vim.log.levels.WARN)
    return
  end

  -- Get containers for selection
  local containers = pod_actions.get_containers(resource)
  if not containers or #containers == 0 then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  local function open_logs(container)
    -- Open in new tab
    vim.cmd("tabnew")

    local adapter = require("k8s.infra.kubectl.adapter")
    local result = adapter.logs(resource.name, container, resource.namespace, {
      follow = true,
      timestamps = true,
    })

    if not result.ok then
      vim.notify("Failed to open logs: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Set tab name
    local tab_name = pod_actions.format_tab_name("logs", resource.name, container)
    vim.api.nvim_buf_set_name(0, tab_name)
  end

  -- If single container, open directly
  if #containers == 1 then
    open_logs(containers[1])
    return
  end

  -- Multiple containers - show selection menu
  vim.ui.select(containers, {
    prompt = "Select Container:",
  }, function(choice)
    if choice then
      open_logs(choice)
    end
  end)
end

---Handle exec action
function M._handle_exec()
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local pod_actions = require("k8s.handlers.pod_actions")

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Exec is only available for Pods", vim.log.levels.WARN)
    return
  end

  -- Get containers for selection
  local containers = pod_actions.get_containers(resource)
  if not containers or #containers == 0 then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  local function open_exec(container)
    -- Open in new tab
    vim.cmd("tabnew")

    -- Capture current buffer for auto-close
    local bufnr = vim.api.nvim_get_current_buf()

    local adapter = require("k8s.infra.kubectl.adapter")
    local result = adapter.exec(resource.name, container, resource.namespace, nil, {
      on_exit = function()
        -- Auto-close tab when shell exits
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            -- Close the buffer (this will close the tab if it's the only buffer)
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end
        end)
      end,
    })

    if not result.ok then
      vim.notify("Failed to exec: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Set tab name
    local tab_name = pod_actions.format_tab_name("exec", resource.name, container)
    vim.api.nvim_buf_set_name(0, tab_name)
  end

  -- If single container, open directly
  if #containers == 1 then
    open_exec(containers[1])
    return
  end

  -- Multiple containers - show selection menu
  vim.ui.select(containers, {
    prompt = "Select Container:",
  }, function(choice)
    if choice then
      open_exec(choice)
    end
  end)
end

---Handle scale action
function M._handle_scale()
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local resource_actions = require("k8s.handlers.resource_actions")

  if not resource_actions.validate_scale_target(resource.kind) then
    vim.notify("Cannot scale " .. resource.kind, vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "Replicas: " }, function(input)
    if input == nil or input == "" then
      return
    end

    local replicas = tonumber(input)
    if not replicas or replicas < 0 then
      vim.notify("Invalid replicas number", vim.log.levels.WARN)
      return
    end

    local adapter = require("k8s.infra.kubectl.adapter")

    adapter.scale(resource.kind, resource.name, resource.namespace, replicas, function(result)
      vim.schedule(function()
        if result.ok then
          vim.notify(
            resource_actions.format_action_result("scale", resource.kind, resource.name, true),
            vim.log.levels.INFO
          )
          M._handle_refresh()
        else
          vim.notify(
            resource_actions.format_action_result("scale", resource.kind, resource.name, false, result.error),
            vim.log.levels.ERROR
          )
        end
      end)
    end)
  end)
end

---Handle restart action
function M._handle_restart()
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local resource_actions = require("k8s.handlers.resource_actions")

  if not resource_actions.validate_restart_target(resource.kind) then
    vim.notify("Cannot restart " .. resource.kind, vim.log.levels.WARN)
    return
  end

  local action = resource_actions.create_restart_action(resource)
  local choice = vim.fn.confirm(action.confirm_message, "&Yes\n&No", 2)

  if choice ~= 1 then
    return
  end

  local adapter = require("k8s.infra.kubectl.adapter")

  adapter.restart(resource.kind, resource.name, resource.namespace, function(result)
    vim.schedule(function()
      if result.ok then
        vim.notify(
          resource_actions.format_action_result("restart", resource.kind, resource.name, true),
          vim.log.levels.INFO
        )
        M._handle_refresh()
      else
        vim.notify(
          resource_actions.format_action_result("restart", resource.kind, resource.name, false, result.error),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

---Handle port forward action
function M._handle_port_forward()
  local resource_mod = require("k8s.domain.resources.resource")

  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  -- Check if port_forward is supported for this resource kind
  local caps = resource_mod.capabilities(resource.kind)
  if not caps.port_forward then
    vim.notify("Port forward is not available for " .. resource.kind, vim.log.levels.WARN)
    return
  end

  -- Get resource prefix and ports based on kind
  local resource_prefix
  local available_ports = {}

  if resource.kind == "Pod" then
    resource_prefix = "pod/"
    local pod_actions = require("k8s.handlers.pod_actions")
    available_ports = pod_actions.get_container_ports(resource)
  elseif resource.kind == "Service" then
    resource_prefix = "svc/"
    -- Get Service ports from spec
    if resource.raw and resource.raw.spec and resource.raw.spec.ports then
      for _, port in ipairs(resource.raw.spec.ports) do
        table.insert(available_ports, {
          port = port.port,
          name = port.name or "",
          protocol = port.protocol or "TCP",
          target_port = port.targetPort,
        })
      end
    end
  elseif resource.kind == "Deployment" then
    resource_prefix = "deployment/"
    -- Get Deployment ports from pod template
    if resource.raw and resource.raw.spec and resource.raw.spec.template then
      local containers = resource.raw.spec.template.spec and resource.raw.spec.template.spec.containers or {}
      for _, container in ipairs(containers) do
        if container.ports then
          for _, port in ipairs(container.ports) do
            table.insert(available_ports, {
              port = port.containerPort,
              name = port.name or "",
              protocol = port.protocol or "TCP",
              container = container.name,
            })
          end
        end
      end
    end
  else
    resource_prefix = resource.kind:lower() .. "/"
  end

  local resource_name = resource_prefix .. resource.name

  -- Helper function to start port forward
  local function start_port_forward(local_port, remote_port)
    local adapter = require("k8s.infra.kubectl.adapter")
    local connections = require("k8s.domain.state.connections")

    local result = adapter.port_forward(resource_name, resource.namespace, local_port, remote_port)

    if result.ok then
      connections.add({
        job_id = result.data.job_id,
        resource = resource_name,
        namespace = resource.namespace,
        local_port = local_port,
        remote_port = remote_port,
      })

      local notify = require("k8s.api.notify")
      local msg = notify.format_port_forward_message(resource_name, local_port, remote_port, "start")
      vim.notify(msg, vim.log.levels.INFO)
    else
      vim.notify("Failed to start port forward: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
    end
  end

  -- If ports exist, show selection menu
  if #available_ports > 0 then
    local options = {}
    for _, port in ipairs(available_ports) do
      local label
      if resource.kind == "Service" then
        if port.name and port.name ~= "" then
          label = string.format("%d/%s (%s)", port.port, port.name, port.protocol)
        else
          label = string.format("%d (%s)", port.port, port.protocol)
        end
      else
        -- Pod
        if port.name and port.name ~= "" then
          label = string.format("%d/%s (%s)", port.port, port.name, port.container)
        else
          label = string.format("%d (%s)", port.port, port.container)
        end
      end
      table.insert(options, { label = label, port = port.port })
    end
    table.insert(options, { label = "Custom port...", port = nil })

    local labels = {}
    for _, opt in ipairs(options) do
      table.insert(labels, opt.label)
    end

    vim.ui.select(labels, {
      prompt = "Select Remote Port:",
    }, function(choice, idx)
      if not choice then
        return
      end

      local selected = options[idx]
      if selected.port then
        -- Auto-detected port selected
        vim.ui.input({ prompt = "Local port: ", default = tostring(selected.port) }, function(local_port_str)
          if local_port_str == nil or local_port_str == "" then
            return
          end
          local local_port = tonumber(local_port_str)
          if not local_port then
            vim.notify("Invalid port number", vim.log.levels.WARN)
            return
          end
          start_port_forward(local_port, selected.port)
        end)
      else
        -- Custom port selected
        M._prompt_custom_port_forward(start_port_forward)
      end
    end)
  else
    -- No ports defined, prompt manually
    M._prompt_custom_port_forward(start_port_forward)
  end
end

---Prompt for custom port forward (when no auto-detected ports)
---@param callback function(local_port: number, remote_port: number)
function M._prompt_custom_port_forward(callback)
  vim.ui.input({ prompt = "Local port: " }, function(local_port_str)
    if local_port_str == nil or local_port_str == "" then
      return
    end

    local local_port = tonumber(local_port_str)
    if not local_port then
      vim.notify("Invalid port number", vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = "Remote port: " }, function(remote_port_str)
      if remote_port_str == nil or remote_port_str == "" then
        return
      end

      local remote_port = tonumber(remote_port_str)
      if not remote_port then
        vim.notify("Invalid port number", vim.log.levels.WARN)
        return
      end

      callback(local_port, remote_port)
    end)
  end)
end

---Handle resource menu action
function M._handle_resource_menu()
  local menu_actions = require("k8s.handlers.menu_actions")
  local view_stack = require("k8s.app.view_stack")
  local window = require("k8s.ui.nui.window")

  -- Save current cursor position before showing menu
  local cursor_row = 1
  if state.window then
    cursor_row = window.get_cursor(state.window)
  end

  local items = menu_actions.get_resource_menu_items()
  local options = {}
  for _, item in ipairs(items) do
    table.insert(options, item.text)
  end

  vim.ui.select(options, {
    prompt = menu_actions.get_menu_title("resource"),
  }, function(choice)
    if not choice then
      return
    end

    for _, item in ipairs(items) do
      if item.text == choice then
        local app = require("k8s.app.app")

        -- Push new list view to stack for back navigation
        state.view_stack = view_stack.push(state.view_stack, {
          type = "list",
          kind = item.value,
          namespace = state.app_state.current_namespace,
          parent_cursor = cursor_row,
        })

        state.app_state = app.set_kind(state.app_state, item.value)
        M._fetch_and_render(item.value, state.app_state.current_namespace)
        break
      end
    end
  end)
end

---Handle context menu action
function M._handle_context_menu()
  local adapter = require("k8s.infra.kubectl.adapter")

  adapter.get_contexts(function(result)
    vim.schedule(function()
      if not result.ok then
        vim.notify("Failed to get contexts: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
        return
      end

      local menu_actions = require("k8s.handlers.menu_actions")

      vim.ui.select(result.data, {
        prompt = menu_actions.get_menu_title("context"),
      }, function(choice)
        if not choice then
          return
        end

        adapter.use_context(choice, function(switch_result)
          vim.schedule(function()
            if switch_result.ok then
              local notify = require("k8s.api.notify")
              vim.notify(notify.format_context_switch_message(choice), vim.log.levels.INFO)
              M._handle_refresh()
            else
              vim.notify("Failed to switch context: " .. (switch_result.error or "Unknown error"), vim.log.levels.ERROR)
            end
          end)
        end)
      end)
    end)
  end)
end

---Handle namespace menu action
function M._handle_namespace_menu()
  local adapter = require("k8s.infra.kubectl.adapter")

  adapter.get_namespaces(function(result)
    vim.schedule(function()
      if not result.ok then
        vim.notify("Failed to get namespaces: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
        return
      end

      local menu_actions = require("k8s.handlers.menu_actions")

      -- Add "All Namespaces" option at the beginning
      local options = { "All Namespaces" }
      for _, ns in ipairs(result.data) do
        table.insert(options, ns)
      end

      vim.ui.select(options, {
        prompt = menu_actions.get_menu_title("namespace"),
      }, function(choice)
        if not choice then
          return
        end

        local app = require("k8s.app.app")
        local namespace = choice == "All Namespaces" and "" or choice
        state.app_state = app.set_namespace(state.app_state, namespace)

        local notify = require("k8s.api.notify")
        vim.notify(notify.format_namespace_switch_message(choice), vim.log.levels.INFO)
        M._fetch_and_render(state.app_state.current_kind, namespace)
      end)
    end)
  end)
end

-- Map help action names to capability names
local help_action_to_capability = {
  Logs = "logs",
  PrevLogs = "logs",
  Exec = "exec",
  Scale = "scale",
  Restart = "restart",
  PortFwd = "port_forward",
}

---Handle help action
function M._handle_help()
  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  local help = require("k8s.ui.views.help")
  local view_stack = require("k8s.app.view_stack")
  local resource_mod = require("k8s.domain.resources.resource")

  -- Get current view type before pushing help
  local current_view = M._get_current_view_type() or "list"
  -- Map to help.lua view names
  local help_view_name = current_view == "list" and "resource_list" or current_view

  -- Get current resource kind for capability filtering
  local current_kind = state.app_state and state.app_state.current_kind

  -- Save current cursor position before pushing new view
  local cursor_row = 1
  if state.window then
    cursor_row = window.get_cursor(state.window)
  end

  -- Push help view to stack
  if not state.view_stack then
    state.view_stack = {}
  end
  state.view_stack = view_stack.push(state.view_stack, {
    type = "help",
    parent_view = current_view,
    parent_cursor = cursor_row,
  })

  -- Get keymaps for the current view
  local view_keymaps = help.get_keymaps_for_view(help_view_name)

  -- Filter keymaps based on resource capabilities
  local filtered_keymaps = {}
  if current_kind then
    local caps = resource_mod.capabilities(current_kind)
    for _, km in ipairs(view_keymaps) do
      local capability = help_action_to_capability[km.action]
      -- Include keymap if action doesn't require capability OR resource has the capability
      if not capability or caps[capability] == true then
        table.insert(filtered_keymaps, km)
      end
    end
  else
    filtered_keymaps = view_keymaps
  end

  local help_lines = {}
  table.insert(help_lines, help.get_help_title())
  table.insert(help_lines, "")

  -- Format keymaps
  local keymap_lines = help.format_keymap_lines(filtered_keymaps, 4)
  for _, line in ipairs(keymap_lines) do
    table.insert(help_lines, line)
  end

  -- Display help in content area
  local content_bufnr = window.get_content_bufnr(state.window)
  if content_bufnr then
    window.set_lines(content_bufnr, help_lines)
  end

  -- Update footer
  M._render_footer("help")
end

---Handle logs_previous action (previous container logs with -p)
function M._handle_logs_previous()
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local pod_actions = require("k8s.handlers.pod_actions")

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Previous logs are only available for Pods", vim.log.levels.WARN)
    return
  end

  -- Get containers for selection
  local containers = pod_actions.get_containers(resource)
  if not containers or #containers == 0 then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  local function open_previous_logs(container)
    -- Open in new tab
    vim.cmd("tabnew")

    local adapter = require("k8s.infra.kubectl.adapter")
    local result = adapter.logs(resource.name, container, resource.namespace, {
      follow = false,
      timestamps = true,
      previous = true,
    })

    if not result.ok then
      vim.notify("Failed to open previous logs: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Set tab name
    local tab_name = pod_actions.format_tab_name("logs-prev", resource.name, container)
    vim.api.nvim_buf_set_name(0, tab_name)
  end

  -- If single container, open directly
  if #containers == 1 then
    open_previous_logs(containers[1])
    return
  end

  -- Multiple containers - show selection menu
  vim.ui.select(containers, {
    prompt = "Select Container:",
  }, function(choice)
    if choice then
      open_previous_logs(choice)
    end
  end)
end

---Handle toggle_secret action
function M._handle_toggle_secret()
  if not state.app_state then
    return
  end

  local app = require("k8s.app.app")

  -- Toggle secret mask state
  local current_mask = state.app_state.mask_secrets
  state.app_state = app.set_mask_secrets(state.app_state, not current_mask)

  local status = state.app_state.mask_secrets and "masked" or "visible"
  vim.notify("Secrets are now " .. status, vim.log.levels.INFO)

  -- Re-render if viewing secrets
  if state.app_state.current_kind == "Secret" then
    M._render_filtered_resources()
  end
end

---Handle port forward list action
function M._handle_port_forward_list()
  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  local view_stack = require("k8s.app.view_stack")
  local connections = require("k8s.domain.state.connections")
  local port_forward_list = require("k8s.ui.views.port_forward_list")

  -- Save current cursor position before pushing new view
  local cursor_row = 1
  if state.window then
    cursor_row = window.get_cursor(state.window)
  end

  -- Push port forward list view to stack
  state.view_stack = view_stack.push(state.view_stack, {
    type = "port_forward_list",
    parent_cursor = cursor_row,
  })

  -- Update footer
  M._render_footer("port_forward_list")

  -- Get active connections
  local active = connections.get_all()

  -- Store connections reference for stop action
  state.pf_list_connections = active

  -- Render port forward list
  local content_bufnr = window.get_content_bufnr(state.window)
  if content_bufnr then
    local lines = port_forward_list.create_content(active)
    window.set_lines(content_bufnr, lines)

    -- Set cursor to first data row if connections exist
    if #active > 0 then
      window.set_cursor(state.window, 2, 0)
    end
  end

  -- Update header
  local header_bufnr = window.get_header_bufnr(state.window)
  if header_bufnr then
    local buffer = require("k8s.ui.nui.buffer")
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = "",
      view = "Port Forwards",
    })
    window.set_lines(header_bufnr, { header_content })
  end
end

---Handle stop port forward action (D key in port forward list view)
function M._handle_stop_port_forward()
  local view_stack = require("k8s.app.view_stack")
  local current = view_stack.current(state.view_stack)

  -- Only allow in port_forward_list view
  if not current or current.type ~= "port_forward_list" then
    return
  end

  if not state.pf_list_connections or #state.pf_list_connections == 0 then
    vim.notify("No active port forwards", vim.log.levels.INFO)
    return
  end

  local window = require("k8s.ui.nui.window")

  -- Get cursor position (1-indexed, row 1 is header)
  local row = window.get_cursor(state.window)
  local cursor_idx = row - 1

  if cursor_idx < 1 or cursor_idx > #state.pf_list_connections then
    vim.notify("No port forward selected", vim.log.levels.WARN)
    return
  end

  local conn = state.pf_list_connections[cursor_idx]
  if not conn then
    return
  end

  -- Stop the port forward job
  pcall(vim.fn.jobstop, conn.job_id)

  -- Remove from connections
  local connections = require("k8s.domain.state.connections")
  connections.remove(conn.job_id)

  -- Notify user
  local notify = require("k8s.api.notify")
  local msg = notify.format_port_forward_message(conn.resource, conn.local_port, conn.remote_port, "stop")
  vim.notify(msg, vim.log.levels.INFO)

  -- Refresh the port forward list view
  M._handle_port_forward_list()
end

return M
