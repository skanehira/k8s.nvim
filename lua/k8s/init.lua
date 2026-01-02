--- init.lua - k8s.nvim メインモジュール

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

---Get current state
---@return table
function M.get_state()
  local global_state = require("k8s.core.global_state")
  return {
    setup_done = global_state.is_setup_done(),
    config = global_state.get_config(),
  }
end

---Check if setup is done
---@return boolean
function M.is_setup_done()
  local global_state = require("k8s.core.global_state")
  return global_state.is_setup_done()
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

---Get keymap definitions
---@return table
function M.get_keymap_definitions()
  return require("k8s.handlers.keymap").get_keymap_definitions()
end

---Get footer keymaps
---@param view_type string
---@param kind? string
---@return table[]
function M.get_footer_keymaps(view_type, kind)
  return require("k8s.handlers.keymap").get_footer_keymaps(view_type, kind)
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
-- Setup
-- =============================================================================

---Setup k8s.nvim
---@param user_config? table
function M.setup(user_config)
  local global_state = require("k8s.core.global_state")

  if global_state.is_setup_done() then
    return
  end

  local config_mod = require("k8s.config")
  local config = config_mod.merge(user_config)

  local valid, err = config_mod.validate(config)
  if not valid then
    vim.notify("k8s.nvim: Invalid config: " .. err, vim.log.levels.ERROR)
    return
  end

  global_state.set_config(config)

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
      local connections = require("k8s.core.connections")
      for _, conn in ipairs(connections.get_all()) do
        pcall(vim.fn.jobstop, conn.job_id)
      end
      connections.clear()
    end,
  })

  global_state.set_setup_done()
end

-- =============================================================================
-- UI Lifecycle
-- =============================================================================

---Setup keymaps for a specific window
---@param win K8sWindow
function M._setup_keymaps_for_window(win)
  local keymap = require("k8s.handlers.keymap")
  local dispatcher = require("k8s.handlers.dispatcher")
  local handlers = dispatcher.create_handlers(M.hide, M._setup_keymaps_for_window, M.close)
  keymap.setup_keymaps_for_window(win, handlers)
end

---Open k8s.nvim UI
---@param opts? { kind?: string }
function M.open(opts)
  opts = opts or {}

  local global_state = require("k8s.core.global_state")

  if not global_state.is_setup_done() then
    M.setup()
  end

  local config = global_state.get_config()

  -- Check kubectl availability
  if not require("k8s.core.health").check_kubectl() then
    vim.notify("k8s.nvim: kubectl not found.", vim.log.levels.ERROR)
    return
  end

  -- Don't open if already open
  local win = global_state.get_window()
  if win then
    local window = require("k8s.ui.nui.window")
    if window.is_mounted(win) then
      return
    end
  end

  local window = require("k8s.ui.nui.window")
  local app = require("k8s.core.state")
  local buffer = require("k8s.ui.nui.buffer")
  local view_stack = require("k8s.core.view_stack")
  local renderer = require("k8s.handlers.renderer")
  local timer = require("k8s.core.timer")

  local list_window = window.create_list_view({ transparent = config.transparent })
  global_state.set_window(list_window)

  local kind = opts.kind or config.default_kind or "Pod"
  local namespace = config.default_namespace or "default"
  global_state.set_app_state(app.create_state({ kind = kind, namespace = namespace }))

  window.mount(list_window)

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

  renderer.render_footer("list", kind)
  M._setup_keymaps_for_window(list_window)

  global_state.set_view_stack(view_stack.push({}, {
    type = "list",
    kind = kind,
    window = list_window,
  }))

  renderer.fetch_and_render(kind, namespace)

  timer.start_auto_refresh(function()
    require("k8s.handlers.dispatcher").dispatch("refresh", M._setup_keymaps_for_window)
  end)
end

---Hide k8s.nvim UI (keeps state for restoration)
function M.hide()
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local timer = require("k8s.core.timer")

  timer.stop_auto_refresh()

  local win = global_state.get_window()
  if win and window.is_visible(win) then
    window.hide(win)
  end
end

---Show k8s.nvim UI (restores hidden window)
function M.show()
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local timer = require("k8s.core.timer")

  local win = global_state.get_window()
  if win and window.is_mounted(win) then
    window.show(win)
    timer.start_auto_refresh(function()
      require("k8s.handlers.dispatcher").dispatch("refresh", M._setup_keymaps_for_window)
    end)
  end
end

---Close k8s.nvim UI (complete cleanup)
function M.close()
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local timer = require("k8s.core.timer")

  timer.stop_auto_refresh()

  local vs = global_state.get_view_stack()
  if vs then
    for _, view in ipairs(vs) do
      if view.window then
        window.unmount(view.window)
      end
    end
  end

  global_state.set_window(nil)
  global_state.set_app_state(nil)
  global_state.set_view_stack(nil)
end

---Toggle k8s.nvim UI (hide if visible, show if hidden, open if not exists)
function M.toggle()
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local win = global_state.get_window()

  if win and window.is_mounted(win) then
    if window.is_visible(win) then
      M.hide()
    else
      M.show()
    end
    return
  end
  M.open()
end

-- =============================================================================
-- Public Commands
-- =============================================================================

---Switch to a specific context
---@param context_name string|nil
function M.switch_context(context_name)
  local global_state = require("k8s.core.global_state")
  local dispatcher = require("k8s.handlers.dispatcher")

  if not context_name then
    if global_state.get_window() then
      dispatcher.dispatch("context_menu", M._setup_keymaps_for_window)
    else
      vim.notify("Context name required. Usage: :K8s context <name>", vim.log.levels.WARN)
    end
    return
  end

  local adapter = require("k8s.infra.kubectl.adapter")
  adapter.use_context(context_name, function(result)
    vim.schedule(function()
      if result.ok then
        vim.notify(require("k8s.core.notify").format_context_switch_message(context_name), vim.log.levels.INFO)
        if global_state.get_window() and global_state.get_app_state() then
          dispatcher.dispatch("refresh", M._setup_keymaps_for_window)
        end
      else
        vim.notify("Failed to switch context: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  end)
end

---Switch to a specific namespace
---@param namespace_name string|nil
function M.switch_namespace(namespace_name)
  local global_state = require("k8s.core.global_state")
  local dispatcher = require("k8s.handlers.dispatcher")

  if not namespace_name then
    if global_state.get_window() then
      dispatcher.dispatch("namespace_menu", M._setup_keymaps_for_window)
    else
      vim.notify("Namespace name required. Usage: :K8s namespace <name>", vim.log.levels.WARN)
    end
    return
  end

  local app = require("k8s.core.state")
  -- Convert CLI "all" to internal "All Namespaces"
  local namespace = namespace_name == "all" and "All Namespaces" or namespace_name

  local app_state = global_state.get_app_state()
  if app_state then
    global_state.set_app_state(app.set_namespace(app_state, namespace))
    vim.notify(require("k8s.core.notify").format_namespace_switch_message(namespace_name), vim.log.levels.INFO)
    app_state = global_state.get_app_state()
    require("k8s.handlers.renderer").fetch_and_render(app_state.current_kind, namespace)
  else
    vim.notify("Namespace set to: " .. namespace_name, vim.log.levels.INFO)
  end
end

---Show port forwards list
function M.show_port_forwards()
  local global_state = require("k8s.core.global_state")
  local dispatcher = require("k8s.handlers.dispatcher")

  if not global_state.get_window() then
    M.open()
    vim.schedule(function()
      dispatcher.dispatch("port_forward_list", M._setup_keymaps_for_window)
    end)
  else
    dispatcher.dispatch("port_forward_list", M._setup_keymaps_for_window)
  end
end

return M
