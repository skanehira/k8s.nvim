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
  back = { key = "<Esc>", action = "back", desc = "Back" },
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
    { key = "<Esc>", action = "back" },
    { key = "q", action = "quit" },
  },
  port_forward_list = {
    { key = "D", action = "delete" },
    { key = "<Esc>", action = "back" },
    { key = "q", action = "quit" },
  },
  help = {
    { key = "<Esc>", action = "back" },
    { key = "q", action = "quit" },
  },
}

---Get keymap definitions
---@return table
function M.get_keymap_definitions()
  return keymap_definitions
end

---Get footer keymaps for a specific view
---@param view_type string
---@return table[]
function M.get_footer_keymaps(view_type)
  return footer_keymaps[view_type] or footer_keymaps.list
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

  state.setup_done = true
end

---Open k8s.nvim UI
---@param opts? { kind?: string }
function M.open(opts)
  opts = opts or {}

  -- Ensure setup was called
  if not state.setup_done then
    M.setup()
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
  state.window = window.create()

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
  M._render_footer("list")

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
function M._render_footer(view_type)
  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")

  local footer_bufnr = window.get_footer_bufnr(state.window)
  if footer_bufnr then
    local keymaps = M.get_footer_keymaps(view_type)
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

  -- quit
  window.map_key(state.window, keymaps.quit.key, function()
    M.close()
  end, { desc = keymaps.quit.desc })

  -- back (in list view, same as quit)
  window.map_key(state.window, keymaps.back.key, function()
    M._handle_back()
  end, { desc = keymaps.back.desc })

  -- describe
  window.map_key(state.window, keymaps.describe.key, function()
    M._handle_describe()
  end, { desc = keymaps.describe.desc })

  -- select (Enter key)
  window.map_key(state.window, keymaps.select.key, function()
    M._handle_describe()
  end, { desc = keymaps.select.desc })

  -- refresh
  window.map_key(state.window, keymaps.refresh.key, function()
    M._handle_refresh()
  end, { desc = keymaps.refresh.desc })

  -- filter
  window.map_key(state.window, keymaps.filter.key, function()
    M._handle_filter()
  end, { desc = keymaps.filter.desc })

  -- delete
  window.map_key(state.window, keymaps.delete.key, function()
    M._handle_delete()
  end, { desc = keymaps.delete.desc })

  -- logs
  window.map_key(state.window, keymaps.logs.key, function()
    M._handle_logs()
  end, { desc = keymaps.logs.desc })

  -- exec
  window.map_key(state.window, keymaps.exec.key, function()
    M._handle_exec()
  end, { desc = keymaps.exec.desc })

  -- scale
  window.map_key(state.window, keymaps.scale.key, function()
    M._handle_scale()
  end, { desc = keymaps.scale.desc })

  -- restart
  window.map_key(state.window, keymaps.restart.key, function()
    M._handle_restart()
  end, { desc = keymaps.restart.desc })

  -- port_forward
  window.map_key(state.window, keymaps.port_forward.key, function()
    M._handle_port_forward()
  end, { desc = keymaps.port_forward.desc })

  -- port_forward_list
  window.map_key(state.window, keymaps.port_forward_list.key, function()
    M._handle_port_forward_list()
  end, { desc = keymaps.port_forward_list.desc })

  -- resource_menu
  window.map_key(state.window, keymaps.resource_menu.key, function()
    M._handle_resource_menu()
  end, { desc = keymaps.resource_menu.desc })

  -- context_menu
  window.map_key(state.window, keymaps.context_menu.key, function()
    M._handle_context_menu()
  end, { desc = keymaps.context_menu.desc })

  -- namespace_menu
  window.map_key(state.window, keymaps.namespace_menu.key, function()
    M._handle_namespace_menu()
  end, { desc = keymaps.namespace_menu.desc })

  -- help
  window.map_key(state.window, keymaps.help.key, function()
    M._handle_help()
  end, { desc = keymaps.help.desc })
end

---Fetch resources and render
---@param kind string
---@param namespace string
function M._fetch_and_render(kind, namespace)
  local window = require("k8s.ui.nui.window")
  local app = require("k8s.app.app")
  local columns = require("k8s.ui.views.columns")
  local buffer = require("k8s.ui.nui.buffer")
  local adapter = require("k8s.infra.kubectl.adapter")
  local table_component = require("k8s.ui.components.table")

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
        window.set_lines(content_bufnr, { "Error: " .. (result.error or "Unknown error") })
        return
      end

      -- Update app state
      state.app_state = app.set_resources(state.app_state, result.data)

      -- Get columns for this kind
      local cols = columns.get_columns(kind)

      -- Extract row data
      local rows = {}
      for _, resource in ipairs(result.data) do
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

      -- Set cursor to first data row
      if #rows > 0 then
        window.set_cursor(state.window, 2, 0)
      end
    end)
  end)
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

  if not state.view_stack or not view_stack.can_pop(state.view_stack) then
    M.close()
    return
  end

  -- pop returns (new_stack, popped_view)
  local new_stack = view_stack.pop(state.view_stack)
  state.view_stack = new_stack

  local current = view_stack.current(state.view_stack)

  if current and current.type == "list" then
    M._render_footer("list")
    M._fetch_and_render(state.app_state.current_kind, state.app_state.current_namespace)
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

  -- Push describe view to stack
  if not state.view_stack then
    state.view_stack = {}
  end
  state.view_stack = view_stack.push(state.view_stack, {
    type = "describe",
    resource = resource,
  })

  -- Update footer
  M._render_footer("describe")

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
        window.set_lines(content_bufnr, { "Error: " .. (result.error or "Unknown error") })
        return
      end

      -- Set lines
      local lines = vim.split(result.data, "\n")
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

  M._fetch_and_render(state.app_state.current_kind, state.app_state.current_namespace)
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

  local container = pod_actions.get_default_container(resource)
  if not container then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

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

  local container = pod_actions.get_default_container(resource)
  if not container then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  -- Open in new tab
  vim.cmd("tabnew")

  local adapter = require("k8s.infra.kubectl.adapter")
  local result = adapter.exec(resource.name, container, resource.namespace)

  if not result.ok then
    vim.notify("Failed to exec: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Set tab name
  local tab_name = pod_actions.format_tab_name("exec", resource.name, container)
  vim.api.nvim_buf_set_name(0, tab_name)
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
  local resource = M._get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local pod_actions = require("k8s.handlers.pod_actions")

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Port forward is only available for Pods", vim.log.levels.WARN)
    return
  end

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

      local adapter = require("k8s.infra.kubectl.adapter")
      local connections = require("k8s.domain.state.connections")

      local pod_resource = "pod/" .. resource.name
      local result = adapter.port_forward(pod_resource, resource.namespace, local_port, remote_port)

      if result.ok then
        -- Add to connections
        if not state.connections then
          state.connections = connections.create()
        end
        state.connections = connections.add(state.connections, {
          job_id = result.data.job_id,
          resource = pod_resource,
          namespace = resource.namespace,
          local_port = local_port,
          remote_port = remote_port,
        })

        local notify = require("k8s.api.notify")
        local msg = notify.format_port_forward_message(pod_resource, local_port, remote_port, "start")
        vim.notify(msg, vim.log.levels.INFO)
      else
        vim.notify("Failed to start port forward: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  end)
end

---Handle port forward list action
function M._handle_port_forward_list()
  vim.notify("Port forward list not yet implemented", vim.log.levels.INFO)
end

---Handle resource menu action
function M._handle_resource_menu()
  local menu_actions = require("k8s.handlers.menu_actions")

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

---Handle help action
function M._handle_help()
  if not state.window then
    return
  end

  local window = require("k8s.ui.nui.window")
  local help = require("k8s.ui.views.help")

  local keymaps = M.get_keymap_definitions()
  local help_lines = help.create_help_content(keymaps)

  local footer_bufnr = window.get_footer_bufnr(state.window)
  if footer_bufnr then
    window.set_lines(footer_bufnr, help_lines)
  end

  -- Set up keypress to close help
  local content_bufnr = window.get_content_bufnr(state.window)
  if content_bufnr then
    vim.api.nvim_buf_set_keymap(content_bufnr, "n", "<Space>", "", {
      noremap = true,
      silent = true,
      callback = function()
        M._render_footer("list")
        vim.api.nvim_buf_del_keymap(content_bufnr, "n", "<Space>")
      end,
    })
  end
end

return M
