--- dispatcher.lua - アクションディスパッチャー

---@class K8sCallbacks
---@field render_footer fun(view_type: string, kind?: string)
---@field fetch_and_render fun(kind: string, namespace: string, opts?: table)
---@field start_watcher fun(kind: string, namespace: string)
---@field setup_keymaps_for_window fun(win: K8sWindow, view_type: string, opts?: { resource_kind?: string })
---@field get_footer_keymaps fun(view_type: string, kind?: string): table[]
---@field handle_refresh? fun()

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
---@return K8sCallbacks
local function create_callbacks(setup_keymaps_fn)
  return {
    render_footer = function(view_type, kind)
      get_renderer().render_footer(view_type, kind)
    end,
    fetch_and_render = function(kind, namespace, opts)
      get_renderer().fetch_and_render(kind, namespace, opts)
    end,
    start_watcher = function(kind, namespace)
      require("k8s")._start_watcher(kind, namespace)
    end,
    render_filtered_resources = function()
      get_list_handler().render_filtered_resources()
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
    get_port_forward_handler().handle_stop_port_forward()
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

-- All dispatchable actions
local action_names = {
  "back",
  "describe",
  "refresh",
  "filter",
  "delete",
  "logs",
  "logs_previous",
  "exec",
  "scale",
  "restart",
  "port_forward",
  "port_forward_list",
  "stop_port_forward",
  "resource_menu",
  "context_menu",
  "namespace_menu",
  "toggle_secret",
  "help",
}

---Create action handlers for keymap setup
---@param hide_fn function
---@param setup_keymaps_fn function
---@param close_fn? function
---@return table
function M.create_handlers(hide_fn, setup_keymaps_fn, close_fn)
  local handlers = {
    hide = hide_fn,
    close = close_fn or hide_fn,
  }

  for _, action in ipairs(action_names) do
    handlers["handle_" .. action] = function()
      dispatch(action, setup_keymaps_fn)
    end
  end

  return handlers
end

return M
