--- dispatcher.lua - アクションディスパッチャー

local M = {}

-- Lazy-loaded modules
local function get_list_handler()
  return require("k8s.handlers.list_handler")
end

local function get_describe_handler()
  return require("k8s.handlers.describe_handler")
end

local function get_port_forward_handler()
  return require("k8s.handlers.port_forward_handler")
end

local function get_menu_handler()
  return require("k8s.handlers.menu_handler")
end

local function get_keymap()
  return require("k8s.handlers.keymap")
end

local function get_renderer()
  return require("k8s.handlers.renderer")
end

-- Forward declarations for circular references
local dispatch

---Create callbacks object for handlers
---@param setup_keymaps_fn function
---@return table
local function create_callbacks(setup_keymaps_fn)
  return {
    render_footer = function(view_type, kind)
      get_renderer().render_footer(view_type, kind)
    end,
    fetch_and_render = function(kind, namespace, opts)
      get_renderer().fetch_and_render(kind, namespace, opts)
    end,
    render_filtered_resources = function()
      get_list_handler().render_filtered_resources({})
    end,
    handle_refresh = function()
      dispatch("refresh", setup_keymaps_fn)
    end,
    handle_port_forward_list = function()
      dispatch("port_forward_list", setup_keymaps_fn)
    end,
    setup_keymaps_for_window = setup_keymaps_fn,
    get_footer_keymaps = function(view_type, kind)
      return get_keymap().get_footer_keymaps(view_type, kind)
    end,
  }
end

---Dispatch an action to the appropriate handler
---@param action string
---@param setup_keymaps_fn function
function dispatch(action, setup_keymaps_fn)
  local callbacks = create_callbacks(setup_keymaps_fn)

  if action == "back" then
    get_list_handler().handle_back(callbacks)
  elseif action == "refresh" then
    get_list_handler().handle_refresh(callbacks)
  elseif action == "filter" then
    get_list_handler().handle_filter(callbacks)
  elseif action == "delete" then
    get_list_handler().handle_delete(callbacks)
  elseif action == "scale" then
    get_list_handler().handle_scale(callbacks)
  elseif action == "restart" then
    get_list_handler().handle_restart(callbacks)
  elseif action == "toggle_secret" then
    get_list_handler().handle_toggle_secret(callbacks)
  elseif action == "describe" then
    get_describe_handler().handle_describe(callbacks)
  elseif action == "logs" then
    get_describe_handler().handle_logs()
  elseif action == "logs_previous" then
    get_describe_handler().handle_logs_previous()
  elseif action == "exec" then
    get_describe_handler().handle_exec()
  elseif action == "port_forward" then
    get_port_forward_handler().handle_port_forward()
  elseif action == "port_forward_list" then
    get_port_forward_handler().handle_port_forward_list(callbacks)
  elseif action == "stop_port_forward" then
    get_port_forward_handler().handle_stop_port_forward(callbacks)
  elseif action == "resource_menu" then
    get_menu_handler().handle_resource_menu(callbacks)
  elseif action == "context_menu" then
    get_menu_handler().handle_context_menu(callbacks)
  elseif action == "namespace_menu" then
    get_menu_handler().handle_namespace_menu(callbacks)
  elseif action == "help" then
    get_menu_handler().handle_help(callbacks)
  end
end

M.dispatch = dispatch

---Create action handlers for keymap setup
---@param close_fn function
---@param setup_keymaps_fn function
---@return table
function M.create_handlers(close_fn, setup_keymaps_fn)
  return {
    close = close_fn,
    handle_back = function()
      dispatch("back", setup_keymaps_fn)
    end,
    handle_describe = function()
      dispatch("describe", setup_keymaps_fn)
    end,
    handle_refresh = function()
      dispatch("refresh", setup_keymaps_fn)
    end,
    handle_filter = function()
      dispatch("filter", setup_keymaps_fn)
    end,
    handle_delete = function()
      dispatch("delete", setup_keymaps_fn)
    end,
    handle_logs = function()
      dispatch("logs", setup_keymaps_fn)
    end,
    handle_logs_previous = function()
      dispatch("logs_previous", setup_keymaps_fn)
    end,
    handle_exec = function()
      dispatch("exec", setup_keymaps_fn)
    end,
    handle_scale = function()
      dispatch("scale", setup_keymaps_fn)
    end,
    handle_restart = function()
      dispatch("restart", setup_keymaps_fn)
    end,
    handle_port_forward = function()
      dispatch("port_forward", setup_keymaps_fn)
    end,
    handle_port_forward_list = function()
      dispatch("port_forward_list", setup_keymaps_fn)
    end,
    handle_stop_port_forward = function()
      dispatch("stop_port_forward", setup_keymaps_fn)
    end,
    handle_resource_menu = function()
      dispatch("resource_menu", setup_keymaps_fn)
    end,
    handle_context_menu = function()
      dispatch("context_menu", setup_keymaps_fn)
    end,
    handle_namespace_menu = function()
      dispatch("namespace_menu", setup_keymaps_fn)
    end,
    handle_toggle_secret = function()
      dispatch("toggle_secret", setup_keymaps_fn)
    end,
    handle_help = function()
      dispatch("help", setup_keymaps_fn)
    end,
  }
end

return M
