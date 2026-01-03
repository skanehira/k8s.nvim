--- init.lua - k8s.nvim メインモジュール
--- State-centric architecture: State is the source of truth, UI is just a projection

local M = {}

-- Command to kind mapping
local command_to_kind = {
  pods = "Pod",
  deployments = "Deployment",
  statefulsets = "StatefulSet",
  daemonsets = "DaemonSet",
  jobs = "Job",
  cronjobs = "CronJob",
  services = "Service",
  configmaps = "ConfigMap",
  secrets = "Secret",
  nodes = "Node",
  namespaces = "Namespace",
  ingresses = "Ingress",
  events = "Event",
  applications = "Application",
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

-- Reverse mapping: Kind -> resource name (e.g., "Ingress" -> "ingresses")
local kind_to_resource = {}
for resource, kind in pairs(command_to_kind) do
  kind_to_resource[kind] = resource
end

---Get kubectl resource name from Kind
---@param kind string Resource kind (e.g., "Pod", "Ingress")
---@return string resource_name kubectl resource name (e.g., "pods", "ingresses")
function M.get_resource_name_from_kind(kind)
  return kind_to_resource[kind] or (string.lower(kind) .. "s")
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

  -- Setup autocmds
  local group = vim.api.nvim_create_augroup("k8s_nvim", { clear = true })

  -- Cleanup port forwards on exit
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

  -- Resize windows when screen size changes
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    pattern = "*",
    desc = "k8s.nvim: resize windows on screen resize",
    callback = function()
      local window = require("k8s.ui.nui.window")

      -- Resize all windows in the view stack
      local view_stack = state.get_view_stack()
      for _, view in ipairs(view_stack) do
        if view.window and window.is_mounted(view.window) then
          window.resize(view.window)
        end
      end
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
  local render = require("k8s.handlers.render")
  state.subscribe(function()
    render.render({ mode = "debounced" })
  end)

  -- Call on_mounted to start watcher
  local lifecycle = require("k8s.handlers.lifecycle")
  lifecycle.call_on_mounted(view_state)
end

---Hide k8s.nvim UI (keeps state for restoration)
function M.hide()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local lifecycle = require("k8s.handlers.lifecycle")

  -- Call on_unmounted for current view (stops watcher for list views)
  local current_view = state.get_current_view()
  lifecycle.call_on_unmounted(current_view)

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
  local lifecycle = require("k8s.handlers.lifecycle")
  lifecycle.call_on_mounted(current_view)
end

---Close k8s.nvim UI (complete cleanup)
function M.close()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local lifecycle = require("k8s.handlers.lifecycle")

  -- Call on_unmounted for current view
  local current_view = state.get_current_view()
  lifecycle.call_on_unmounted(current_view)

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

    local resource_actions = require("k8s.handlers.resource_actions")
    resource_actions.execute(action, resource, M._setup_keymaps)
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
    local navigation = require("k8s.handlers.navigation")
    navigation.show_help(M._setup_keymaps)
  elseif action == "resource_menu" then
    local navigation = require("k8s.handlers.navigation")
    navigation.show_resource_menu(M._setup_keymaps)
  elseif action == "context_menu" then
    local navigation = require("k8s.handlers.navigation")
    navigation.show_context_menu()
  elseif action == "namespace_menu" then
    local navigation = require("k8s.handlers.navigation")
    navigation.show_namespace_menu()
  elseif action == "port_forward_list" then
    M.show_port_forwards()
  elseif action == "toggle_secret" then
    local resource_actions = require("k8s.handlers.resource_actions")
    resource_actions.toggle_secret()
  elseif action == "stop" then
    -- For port forward list view
    local resource_actions = require("k8s.handlers.resource_actions")
    resource_actions.stop_port_forward()
  end
end

---Handle back action - restore previous view and window
function M._handle_back()
  local lifecycle = require("k8s.handlers.lifecycle")
  -- Use lifecycle-aware pop function
  lifecycle.pop_view(M._setup_keymaps)
end

-- =============================================================================
-- Public Commands
-- =============================================================================

---Switch to a specific context
---@param context_name string|nil
function M.switch_context(context_name)
  local commands = require("k8s.commands")
  commands.switch_context(context_name)
end

---Switch to a specific namespace
---@param namespace_name string|nil
function M.switch_namespace(namespace_name)
  local commands = require("k8s.commands")
  commands.switch_namespace(namespace_name)
end

---Show port forwards list
function M.show_port_forwards()
  local state = require("k8s.state")
  local window = require("k8s.ui.nui.window")
  local port_forward_view = require("k8s.views.port_forward")
  local lifecycle = require("k8s.handlers.lifecycle")
  local render = require("k8s.handlers.render")
  local config = state.get_config() or {}

  local push_port_forward_view = function()
    -- Create new list view window
    local new_win = window.create_list_view({ transparent = config.transparent })
    window.mount(new_win)

    -- Create view state using factory
    local view_state = port_forward_view.create_view({
      window = new_win,
    })

    -- Use lifecycle-aware push
    lifecycle.push_view(view_state, M._setup_keymaps)

    -- Render immediately
    render.render()
  end

  if not state.get_window() then
    M.open()
    vim.schedule(push_port_forward_view)
  else
    push_port_forward_view()
  end
end

return M
