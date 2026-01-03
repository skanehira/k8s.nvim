--- init.lua - k8s.nvim メインモジュール
--- State-centric architecture: State is the source of truth, UI is just a projection

local M = {}

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

-- =============================================================================
-- Public API
-- =============================================================================

---Get current state (read-only snapshot)
---@return table
function M.get_state()
  local state = require("k8s.state")
  return {
    setup_done = state.is_setup_done(),
    config = state.get_config(),
    context = state.get_context(),
    namespace = state.get_namespace(),
    current_view = state.get_current_view(),
  }
end

---Check if setup is done
---@return boolean
function M.is_setup_done()
  return require("k8s.state").is_setup_done()
end

---Create highlight definitions
---@return table
function M.create_highlights()
  return {
    K8sStatusRunning = { fg = "#50fa7b" },
    K8sStatusPending = { fg = "#f1fa8c" },
    K8sStatusError = { fg = "#ff5555" },
    K8sHeader = { fg = "#8be9fd", bold = true },
    K8sFooter = { fg = "#6272a4" },
    K8sTableHeader = { fg = "#bd93f9", bold = true },
    K8sNormal = { bg = "NONE" },
    K8sCursorLine = { bg = "#44475a" },
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

---Check if kubectl is available
---@return boolean
function M.check_kubectl()
  return vim.fn.executable("kubectl") == 1
end

-- =============================================================================
-- Setup
-- =============================================================================

---Setup k8s.nvim
---@param user_config? table
function M.setup(user_config)
  local state = require("k8s.state")

  if state.is_setup_done() then
    return
  end

  local config_mod = require("k8s.config")
  local config = config_mod.merge(user_config)

  local valid, err = config_mod.validate(config)
  if not valid then
    vim.notify("k8s.nvim: Invalid config: " .. err, vim.log.levels.ERROR)
    return
  end

  state.set_config(config)

  -- Setup highlight groups
  for name, hl in pairs(M.create_highlights()) do
    vim.api.nvim_set_hl(0, name, hl)
  end

  -- Setup VimLeavePre autocmd
  local group = vim.api.nvim_create_augroup("k8s_nvim", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    pattern = "*",
    desc = "k8s.nvim: cleanup all port forwards",
    callback = function()
      local connections = require("k8s.handlers.connections")
      for _, conn in ipairs(connections.get_all()) do
        pcall(vim.fn.jobstop, conn.job_id)
      end
      connections.clear()
    end,
  })

  state.set_setup_done()
end

-- =============================================================================
-- UI Lifecycle
-- =============================================================================

---Open k8s.nvim UI
---@param opts? { kind?: string }
function M.open(opts)
  opts = opts or {}

  local state = require("k8s.state")

  if not state.is_setup_done() then
    M.setup()
  end

  local config = state.get_config()
  assert(config, "config is nil")

  -- Check kubectl availability
  if not M.check_kubectl() then
    vim.notify("k8s.nvim: kubectl not found.", vim.log.levels.ERROR)
    return
  end

  -- Check if window already exists
  local win = state.get_window()
  if win then
    local window = require("k8s.ui.nui.window")
    if window.is_mounted(win) then
      if window.is_visible(win) then
        -- Already visible, do nothing
        return
      else
        -- Hidden, check if requested kind matches current view
        local current_view = state.get_current_view()
        local requested_kind = opts.kind or config.default_kind or "Pod"
        local current_kind = current_view and state.get_kind_from_view_type(current_view.type)

        if current_kind == requested_kind then
          -- Same kind, just restore
          M.show()
          return
        else
          -- Different kind requested, close and reopen
          M.close()
          -- Fall through to create new window
        end
      end
    end
  end

  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")
  local list_view = require("k8s.views.list")

  local kind = opts.kind or config.default_kind or "Pod"
  local namespace = config.default_namespace or "default"

  -- Set initial namespace in state
  state.set_namespace(namespace)

  -- Create window
  local list_window = window.create_list_view({ transparent = config.transparent })
  window.mount(list_window)
  state.set_window(list_window)

  -- Create view state using factory
  local view_state = list_view.create_view(kind, {
    window = list_window,
  })

  -- Push view to stack (without calling on_mounted yet)
  state.push_view(view_state)

  -- Setup keymaps
  M._setup_keymaps(list_window)

  -- Render initial header
  local header_bufnr = window.get_header_bufnr(list_window)
  if header_bufnr then
    window.set_lines(header_bufnr, {
      buffer.create_header_content({
        context = "loading...",
        namespace = namespace,
        view = kind .. "s",
        loading = true,
      }),
    })
  end

  -- Subscribe to state changes for rendering
  state.subscribe(function()
    M._render()
  end)

  -- Call on_mounted to start watcher
  M._call_on_mounted(view_state)
end

---Hide k8s.nvim UI (keeps state for restoration)
function M.hide()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  -- Call on_unmounted for current view (stops watcher for list views)
  local current_view = state.get_current_view()
  M._call_on_unmounted(current_view)

  -- Use window from current view (might be different from global window for stacked views)
  local win = current_view and current_view.window or state.get_window()
  if win and window.is_visible(win) then
    window.hide(win)
  end
end

---Show k8s.nvim UI (restores hidden window)
function M.show()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  local current_view = state.get_current_view()
  if not current_view then
    -- No view to restore, open fresh
    M.open()
    return
  end

  -- Use window from current view (might be different from global window for stacked views)
  local win = current_view.window or state.get_window()
  if not win or not window.is_mounted(win) then
    -- Window was destroyed, need to recreate
    M.close()
    M.open()
    return
  end

  window.show(win)
  state.set_window(win)

  -- Call on_mounted to restart watcher (for list views) or render (for other views)
  M._call_on_mounted(current_view)
end

---Close k8s.nvim UI (complete cleanup)
function M.close()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  -- Call on_unmounted for current view
  local current_view = state.get_current_view()
  M._call_on_unmounted(current_view)

  state.unsubscribe()

  local win = state.get_window()
  if win then
    window.unmount(win)
  end

  state.set_window(nil)
  state.clear_view_stack()
end

---Toggle k8s.nvim UI (hide if visible, show if hidden, open if not exists)
function M.toggle()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  -- If we have views in the stack, try to restore
  local view_stack = state.get_view_stack()
  if #view_stack > 0 then
    local current_view = state.get_current_view()
    local win = current_view and current_view.window or state.get_window()

    if win and window.is_mounted(win) then
      if window.is_visible(win) then
        M.hide()
      else
        -- Window is hidden, show it
        M.show()
      end
      return
    end
    -- Window was destroyed externally, clean up and open fresh
    M.close()
  end

  M.open()
end

-- =============================================================================
-- View Lifecycle Management
-- =============================================================================

---Call on_unmounted callback for current view
---@param view ViewState|nil
function M._call_on_unmounted(view)
  if view and view.on_unmounted then
    view.on_unmounted(view)
  end
end

---Call on_mounted callback for view
---@param view ViewState|nil
function M._call_on_mounted(view)
  if view and view.on_mounted then
    view.on_mounted(view)
  end
end

---Push a new view to stack with proper lifecycle management
---@param new_view ViewState
function M._push_view_with_lifecycle(new_view)
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  -- Get current view and call on_unmounted
  local current_view = state.get_current_view()
  if current_view then
    M._call_on_unmounted(current_view)

    -- Save current cursor position
    local current_win = current_view.window or state.get_window()
    if current_win and window.is_mounted(current_win) then
      local cursor_pos = window.get_cursor(current_win)
      state.save_current_view_state(cursor_pos, current_win)
      window.hide(current_win)
    end
  end

  -- Push new view to stack
  state.push_view(new_view)
  state.set_window(new_view.window)

  -- Setup keymaps for new view
  M._setup_keymaps(new_view.window)

  -- Call on_mounted for new view
  M._call_on_mounted(new_view)
end

---Pop current view from stack with proper lifecycle management
function M._pop_view_with_lifecycle()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")

  if not state.can_pop_view() then
    return
  end

  -- Suppress intermediate redraws to prevent flickering
  local lazyredraw_was = vim.o.lazyredraw
  vim.o.lazyredraw = true

  -- Get current view and call on_unmounted
  local current_view = state.get_current_view()
  if current_view then
    M._call_on_unmounted(current_view)

    -- Unmount current window
    local current_win = current_view.window
    if current_win then
      window.unmount(current_win)
    end
  end

  -- Pop view from stack
  state.pop_view()

  -- Get previous view (now current) and restore
  local prev_view = state.get_current_view()
  if not prev_view then
    vim.o.lazyredraw = lazyredraw_was
    return
  end

  -- Show or recreate previous window
  local prev_win = prev_view.window
  local config = state.get_config() or {}

  if prev_win and window.is_mounted(prev_win) and window.has_valid_buffers(prev_win) then
    -- Render before show to prevent stale content flash
    if prev_view.render then
      prev_view.render(prev_view, prev_win)
    end
    window.show(prev_win)
  else
    -- Recreate window based on view type
    if state.is_list_view(prev_view.type) then
      prev_win = window.create_list_view({ transparent = config.transparent })
    else
      prev_win = window.create_detail_view({ transparent = config.transparent })
    end
    window.mount(prev_win)

    -- Update view with new window reference
    state.update_view(function(v)
      return vim.tbl_extend("force", v, { window = prev_win })
    end)

    -- Render after mount
    if prev_view.render then
      prev_view.render(prev_view, prev_win)
    end
  end

  state.set_window(prev_win)

  -- Setup keymaps
  M._setup_keymaps(prev_win)

  -- Restore cursor position
  if prev_view.cursor then
    window.set_cursor(prev_win, prev_view.cursor)
  end

  -- Call on_mounted for previous view
  M._call_on_mounted(prev_view)

  -- Restore lazyredraw and force a single redraw
  vim.o.lazyredraw = lazyredraw_was
  vim.cmd("redraw")
end

-- =============================================================================
-- Keymaps (internal)
-- =============================================================================

---Setup keymaps for the window
---@param win K8sWindow
function M._setup_keymaps(win)
  local window = require("k8s.ui.nui.window")
  local keymaps = require("k8s.views.keymaps")
  local state = require("k8s.state")

  local current_view = state.get_current_view()
  if not current_view then
    return
  end

  local keymap_defs = keymaps.get_keymaps(current_view.type)

  for _, km in ipairs(keymap_defs) do
    window.map_key(win, km.key, function()
      M._handle_action(km.action)
    end, { desc = km.desc })
  end
end

---Handle keymap action
---@param action string
function M._handle_action(action)
  local state = require("k8s.state")
  local keymaps = require("k8s.views.keymaps")
  local list_view = require("k8s.views.list")

  local current_view = state.get_current_view()
  if not current_view then
    return
  end

  -- Check if action is allowed for this view type
  if not keymaps.is_action_allowed(current_view.type, action) then
    return
  end

  -- Navigation actions (always allowed when view permits)
  if action == "quit" then
    M.hide()
    return
  elseif action == "close" then
    M.close()
    return
  elseif action == "back" then
    M._handle_back()
    return
  end

  -- Resource actions require a selected resource
  if keymaps.requires_resource_selection(action) then
    local window = require("k8s.ui.nui.window")
    local win = state.get_window()
    if not win then
      return
    end

    local cursor_pos = window.get_cursor(win)
    local filtered = list_view.filter_resources(current_view.resources, current_view.filter)
    local resource = list_view.get_resource_at_cursor(filtered, cursor_pos)

    if not resource then
      vim.notify("No resource selected", vim.log.levels.WARN)
      return
    end

    M._execute_resource_action(action, resource)
    return
  end

  -- Other actions
  if action == "refresh" then
    local watcher = require("k8s.handlers.watcher")
    state.clear_resources()
    watcher.restart({})
  elseif action == "filter" then
    local current_filter = current_view.filter or ""
    vim.ui.input({ prompt = "Filter: ", default = current_filter }, function(input)
      if input then
        state.set_filter(input)
      end
    end)
  elseif action == "help" then
    M._show_help()
  elseif action == "resource_menu" then
    M._show_resource_menu()
  elseif action == "context_menu" then
    M._show_context_menu()
  elseif action == "namespace_menu" then
    M._show_namespace_menu()
  elseif action == "port_forward_list" then
    M.show_port_forwards()
  elseif action == "toggle_secret" then
    M._toggle_secret()
  elseif action == "stop" then
    -- For port forward list view
    M._stop_port_forward()
  end
end

---Handle back action - restore previous view and window
function M._handle_back()
  -- Use lifecycle-aware pop function
  M._pop_view_with_lifecycle()
end

---Push a detail view with a new window using lifecycle management
---@param view_state ViewState View state to push (must have on_mounted, on_unmounted, render)
function M._push_detail_view(view_state)
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local config = state.get_config() or {}

  -- Suppress intermediate redraws to prevent flickering
  local lazyredraw_was = vim.o.lazyredraw
  vim.o.lazyredraw = true

  -- Create new detail view window
  local new_win = window.create_detail_view({ transparent = config.transparent })
  window.mount(new_win)

  -- Store window reference in view state
  view_state.window = new_win

  -- Use lifecycle-aware push
  M._push_view_with_lifecycle(view_state)

  -- Immediately render to avoid empty buffer flash (bypass debounce)
  if view_state.render then
    view_state.render(view_state, new_win)
  end

  -- Restore lazyredraw and force a single redraw
  vim.o.lazyredraw = lazyredraw_was
  vim.cmd("redraw")
end

---Show help view
function M._show_help()
  local state = require("k8s.state")
  local help = require("k8s.views.help")

  local current_view = state.get_current_view()
  if not current_view then
    return
  end

  -- Create help view using factory
  local view_state = help.create_view(current_view.type)

  -- Push help view with new detail window
  M._push_detail_view(view_state)
end

---Show resource menu
function M._show_resource_menu()
  local state = require("k8s.state")
  local actions = require("k8s.handlers.actions")
  local window = require("k8s.ui.nui.window")
  local list_view = require("k8s.views.list")

  local items = actions.get_resource_menu_items()
  local options = {}
  for _, item in ipairs(items) do
    table.insert(options, item.text)
  end

  vim.ui.select(options, {
    prompt = actions.get_menu_title("resource"),
  }, function(choice)
    if not choice then
      return
    end

    for _, item in ipairs(items) do
      if item.text == choice then
        local kind = item.value
        local view_type = kind:lower() .. "_list"

        -- Check if switching to same resource type
        local current_view = state.get_current_view()
        if current_view and current_view.type == view_type then
          return
        end

        -- Suppress intermediate redraws to prevent flickering
        local lazyredraw_was = vim.o.lazyredraw
        vim.o.lazyredraw = true

        -- Create new list view window
        local config = state.get_config() or {}
        local new_win = window.create_list_view({ transparent = config.transparent })
        window.mount(new_win)

        -- Create view state using factory (namespace is taken from state in on_mounted)
        local view_state = list_view.create_view(kind, {
          window = new_win,
        })

        -- Use lifecycle-aware push
        M._push_view_with_lifecycle(view_state)

        -- Immediately render to avoid empty buffer flash
        if view_state.render then
          view_state.render(view_state, new_win)
        end

        -- Restore lazyredraw and force a single redraw
        vim.o.lazyredraw = lazyredraw_was
        vim.cmd("redraw")
        break
      end
    end
  end)
end

---Show context menu
function M._show_context_menu()
  local adapter = require("k8s.adapters.kubectl.adapter")
  local actions = require("k8s.handlers.actions")
  local notify = require("k8s.handlers.notify")
  local watcher = require("k8s.handlers.watcher")
  local state = require("k8s.state")

  adapter.get_contexts(function(result)
    vim.schedule(function()
      if not result.ok then
        notify.error("Failed to get contexts: " .. (result.error or "Unknown error"))
        return
      end

      vim.ui.select(result.data, {
        prompt = actions.get_menu_title("context"),
      }, function(choice)
        if not choice then
          return
        end

        adapter.use_context(choice, function(switch_result)
          vim.schedule(function()
            if switch_result.ok then
              state.set_context(choice)
              notify.info("Switched to context: " .. choice)

              -- Refresh resources for new context
              state.clear_resources()
              watcher.restart({})
            else
              notify.error("Failed to switch context: " .. (switch_result.error or "Unknown error"))
            end
          end)
        end)
      end)
    end)
  end)
end

---Show namespace menu
function M._show_namespace_menu()
  local adapter = require("k8s.adapters.kubectl.adapter")
  local actions = require("k8s.handlers.actions")
  local notify = require("k8s.handlers.notify")
  local watcher = require("k8s.handlers.watcher")
  local state = require("k8s.state")

  adapter.get_namespaces(function(result)
    vim.schedule(function()
      if not result.ok then
        notify.error("Failed to get namespaces: " .. (result.error or "Unknown error"))
        return
      end

      -- Add "All Namespaces" option at the beginning
      local options = { "All Namespaces" }
      for _, ns in ipairs(result.data) do
        table.insert(options, ns)
      end

      vim.ui.select(options, {
        prompt = actions.get_menu_title("namespace"),
      }, function(choice)
        if not choice then
          return
        end

        state.set_namespace(choice)
        notify.info("Switched to namespace: " .. choice)

        -- Restart watcher with new namespace
        watcher.restart({})
      end)
    end)
  end)
end

---Toggle secret masking in describe view
function M._toggle_secret()
  local state = require("k8s.state")
  local adapter = require("k8s.adapters.kubectl.adapter")

  local current_view = state.get_current_view()
  if not current_view then
    return
  end

  -- Only works for secret_describe view
  if current_view.type ~= "secret_describe" then
    return
  end

  -- Toggle mask_secrets
  local new_mask = current_view.mask_secrets ~= true

  if new_mask then
    -- Masking secrets - just update state and re-render
    state.set_mask_secrets(true)
    vim.notify("Secrets masked", vim.log.levels.INFO)
  else
    -- Revealing secrets - fetch actual secret data
    local resource = current_view.resource
    if not resource then
      return
    end

    adapter.get_secret_data(resource.name, resource.namespace, function(result)
      vim.schedule(function()
        if result.ok then
          -- Store secret_data in view state
          state.update_view(function(v)
            return vim.tbl_extend("force", v, {
              mask_secrets = false,
              secret_data = result.data,
            })
          end)
          vim.notify("Secrets revealed", vim.log.levels.INFO)
        else
          vim.notify("Failed to get secret data: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
        end
      end)
    end)
  end
end

---Stop port forward at cursor
function M._stop_port_forward()
  local state = require("k8s.state")
  local connections = require("k8s.handlers.connections")
  local notify = require("k8s.handlers.notify")
  local window = require("k8s.ui.nui.window")

  local current_view = state.get_current_view()
  if not current_view or current_view.type ~= "port_forward_list" then
    return
  end

  local win = state.get_window()
  if not win then
    return
  end

  local cursor_pos = window.get_cursor(win)
  local all_connections = connections.get_all()

  if cursor_pos < 1 or cursor_pos > #all_connections then
    vim.notify("No port forward selected", vim.log.levels.WARN)
    return
  end

  local conn = all_connections[cursor_pos]
  if conn then
    connections.remove(conn.job_id)
    notify.info("Stopped port forward: " .. conn.resource .. " " .. conn.local_port .. ":" .. conn.remote_port)
    state.notify()
  end
end

---Handle port forward action for a resource
---@param resource table
function M._handle_port_forward(resource)
  local actions = require("k8s.handlers.actions")

  -- Get container ports from the resource
  local ports = actions.get_container_ports(resource)

  if #ports == 0 then
    vim.notify("No ports available for this resource", vim.log.levels.WARN)
    return
  end

  -- Create port options for selection
  local options = {}
  for _, port in ipairs(ports) do
    local label = string.format("%d/%s", port.port, port.protocol)
    if port.name and port.name ~= "" then
      label = label .. " (" .. port.name .. ")"
    end
    table.insert(options, { text = label, port = port })
  end

  -- If only one port, use it directly
  if #options == 1 then
    local port = options[1].port
    vim.ui.input({ prompt = "Local port (default: " .. port.port .. "): " }, function(input)
      if input == nil then
        return -- User cancelled
      end
      local local_port = tonumber(input)
      if not local_port or local_port <= 0 then
        local_port = port.port
      end
      M._start_port_forward(resource, local_port, port.port)
    end)
    return
  end

  -- Show port selection menu
  local option_texts = {}
  for _, opt in ipairs(options) do
    table.insert(option_texts, opt.text)
  end

  vim.ui.select(option_texts, {
    prompt = actions.get_menu_title("container"),
  }, function(choice, idx)
    if not choice or not idx then
      return
    end

    local port = options[idx].port
    vim.ui.input({ prompt = "Local port (default: " .. port.port .. "): " }, function(input)
      if input == nil then
        return -- User cancelled
      end
      local local_port = tonumber(input)
      if not local_port or local_port <= 0 then
        local_port = port.port
      end
      M._start_port_forward(resource, local_port, port.port)
    end)
  end)
end

---Start port forward
---@param resource table
---@param local_port number
---@param remote_port number
function M._start_port_forward(resource, local_port, remote_port)
  local adapter = require("k8s.adapters.kubectl.adapter")
  local connections = require("k8s.handlers.connections")
  local notify = require("k8s.handlers.notify")

  local resource_name = resource.kind:lower() .. "/" .. resource.name

  local result = adapter.port_forward(resource_name, resource.namespace, local_port, remote_port)

  if result.ok then
    connections.add({
      job_id = result.data.job_id,
      resource = resource_name,
      namespace = resource.namespace,
      local_port = local_port,
      remote_port = remote_port,
    })
    notify.info("Port forward started: " .. resource_name .. " " .. local_port .. ":" .. remote_port)
  else
    notify.error("Failed to start port forward: " .. (result.error or "Unknown error"))
  end
end

---Execute action on a specific resource
---@param action string
---@param resource table
function M._execute_resource_action(action, resource)
  local adapter = require("k8s.adapters.kubectl.adapter")
  local notify = require("k8s.handlers.notify")
  local describe_view = require("k8s.views.describe")

  local kind = resource.kind
  local name = resource.name
  local namespace = resource.namespace

  if action == "select" or action == "describe" then
    -- Show describe view with new detail window
    adapter.describe(kind, name, namespace, function(result)
      vim.schedule(function()
        if result.ok then
          -- Create describe view using factory
          local view_state = describe_view.create_view(kind, resource, {
            describe_output = result.data,
          })
          M._push_detail_view(view_state)
        else
          notify.error("Failed to describe " .. kind .. ": " .. (result.error or "Unknown error"))
        end
      end)
    end)
  elseif action == "delete" then
    vim.ui.input({ prompt = "Delete " .. name .. "? (yes/no): " }, function(input)
      if input == "yes" then
        adapter.delete(kind, name, namespace, function(result)
          vim.schedule(function()
            notify.action_result("delete", kind, name, result.ok, result.error)
          end)
        end)
      end
    end)
  elseif action == "logs" then
    local actions = require("k8s.handlers.actions")
    local container = actions.get_default_container(resource)
    if container then
      local tab_name = actions.format_tab_name("logs", name, container)
      adapter.logs(name, container, namespace, { follow = true, tab_name = tab_name })
    end
  elseif action == "logs_previous" then
    local actions = require("k8s.handlers.actions")
    local container = actions.get_default_container(resource)
    if container then
      local tab_name = actions.format_tab_name("logs-prev", name, container)
      adapter.logs(name, container, namespace, { previous = true, tab_name = tab_name })
    end
  elseif action == "exec" then
    local actions = require("k8s.handlers.actions")
    local container = actions.get_default_container(resource)
    if container then
      local tab_name = actions.format_tab_name("exec", name, container)
      adapter.exec(name, container, namespace, nil, { tab_name = tab_name })
    end
  elseif action == "port_forward" then
    M._handle_port_forward(resource)
  elseif action == "scale" then
    vim.ui.input({ prompt = "Scale replicas: " }, function(input)
      local replicas = tonumber(input)
      if replicas then
        adapter.scale(kind, name, namespace, replicas, function(result)
          vim.schedule(function()
            notify.action_result("scale", kind, name, result.ok, result.error)
          end)
        end)
      end
    end)
  elseif action == "restart" then
    adapter.restart(kind, name, namespace, function(result)
      vim.schedule(function()
        notify.action_result("restart", kind, name, result.ok, result.error)
      end)
    end)
  end
end

-- =============================================================================
-- Rendering (internal)
-- =============================================================================

-- Debounce timer for UI updates
local render_timer = nil
local DEBOUNCE_MS = 100

---Debounced render function (called by state listener)
---Delegates rendering to view's render function if available
function M._render()
  if render_timer then
    render_timer:stop()
  end

  ---@diagnostic disable-next-line: undefined-field
  render_timer = vim.uv.new_timer()
  if not render_timer then
    return
  end

  render_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    render_timer:stop()
    render_timer:close()
    render_timer = nil

    local state = require("k8s.state")
    local window = require("k8s.ui.nui.window")

    local win = state.get_window()
    local current_view = state.get_current_view()
    if not win or not current_view or not window.is_mounted(win) then
      return
    end

    -- Delegate to view's render function if available
    if current_view.render then
      current_view.render(current_view, win)
    else
      -- Fallback for views without render function (legacy support)
      M._render_fallback(win, current_view)
    end
  end))
end

---Fallback render for views without render function
---@param win K8sWindow
---@param current_view table
function M._render_fallback(win, current_view)
  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")
  local keymaps = require("k8s.views.keymaps")

  local view_type = current_view.type

  -- Update footer for all views
  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local footer_keymaps = keymaps.get_footer_keymaps(view_type)
    local footer_content = buffer.create_footer_content(footer_keymaps)
    window.set_lines(footer_bufnr, { footer_content })
  end
end

-- =============================================================================
-- Public Commands
-- =============================================================================

---Switch to a specific context
---@param context_name string|nil
function M.switch_context(context_name)
  local state = require("k8s.state")
  local notify = require("k8s.handlers.notify")

  if not context_name then
    vim.notify("Context name required. Usage: :K8s context <name>", vim.log.levels.WARN)
    return
  end

  local adapter = require("k8s.adapters.kubectl.adapter")
  adapter.use_context(context_name, function(result)
    vim.schedule(function()
      if result.ok then
        state.set_context(context_name)
        notify.info("Switched to context: " .. context_name)
      else
        notify.error("Failed to switch context: " .. (result.error or "Unknown error"))
      end
    end)
  end)
end

---Switch to a specific namespace
---@param namespace_name string|nil
function M.switch_namespace(namespace_name)
  local state = require("k8s.state")
  local notify = require("k8s.handlers.notify")
  local watcher = require("k8s.handlers.watcher")

  if not namespace_name then
    vim.notify("Namespace name required. Usage: :K8s namespace <name>", vim.log.levels.WARN)
    return
  end

  -- Convert CLI "all" to internal "All Namespaces"
  local namespace = namespace_name == "all" and "All Namespaces" or namespace_name

  state.set_namespace(namespace)
  notify.info("Switched to namespace: " .. namespace_name)

  -- Restart watcher with new namespace (event handling is done inside watcher.lua)
  watcher.restart({})
end

---Show port forwards list
function M.show_port_forwards()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local port_forward_view = require("k8s.views.port_forward")
  local config = state.get_config() or {}

  local push_port_forward_view = function()
    -- Suppress intermediate redraws to prevent flickering
    local lazyredraw_was = vim.o.lazyredraw
    vim.o.lazyredraw = true

    -- Create new list view window
    local new_win = window.create_list_view({ transparent = config.transparent })
    window.mount(new_win)

    -- Create view state using factory
    local view_state = port_forward_view.create_view({
      window = new_win,
    })

    -- Use lifecycle-aware push
    M._push_view_with_lifecycle(view_state)

    -- Immediately render to avoid empty buffer flash
    if view_state.render then
      view_state.render(view_state, new_win)
    end

    -- Restore lazyredraw and force a single redraw
    vim.o.lazyredraw = lazyredraw_was
    vim.cmd("redraw")
  end

  if not state.get_window() then
    M.open()
    vim.schedule(push_port_forward_view)
  else
    push_port_forward_view()
  end
end

return M
