--- keymap.lua - キーマップ定義とセットアップ

local M = {}

---Build keymap definitions from config
---@return table
local function build_keymap_definitions()
  local global_state = require("k8s.core.global_state")
  local config = global_state.get_config()
  local keymaps = config and config.keymaps or require("k8s.config").get_defaults().keymaps

  local definitions = {}
  for action, def in pairs(keymaps) do
    if type(def) == "table" and def.key then
      definitions[action] = { key = def.key, action = action, desc = def.desc or action }
    end
  end
  return definitions
end

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
    { key = "S", action = "toggle_secret" },
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
    close = true,
    back = true,
  },
  describe = {
    back = true,
    logs = true,
    exec = true,
    delete = true,
    toggle_secret = true,
    quit = true,
    close = true,
    help = true,
  },
  port_forward_list = {
    back = true,
    stop = true, -- D key in port_forward_list stops the connection
    quit = true,
    close = true,
    help = true,
  },
  help = {
    back = true,
    quit = true,
    close = true,
  },
}

-- Map action names to resource capability names
local action_to_capability = {
  logs = "logs",
  logs_previous = "logs",
  exec = "exec",
  scale = "scale",
  restart = "restart",
  port_forward = "port_forward",
}

---Get keymap definitions
---@return table
function M.get_keymap_definitions()
  return build_keymap_definitions()
end

---Get current view type from view stack
---@return string|nil
function M.get_current_view_type()
  local global_state = require("k8s.core.global_state")
  local view_stack = require("k8s.core.view_stack")

  local vs = global_state.get_view_stack()
  if not vs then
    return nil
  end

  local current = view_stack.current(vs)
  return current and current.type or nil
end

---Check if an action is allowed for the current view
---@param action string
---@return boolean
function M.is_action_allowed(action)
  local view_type = M.get_current_view_type()
  if not view_type then
    return false
  end
  local allowed = view_allowed_actions[view_type]
  return allowed and allowed[action] == true
end

---Get current resource at cursor position
---@return table|nil
local function get_current_resource()
  local global_state = require("k8s.core.global_state")
  local app = require("k8s.core.state")
  local window = require("k8s.ui.nui.window")

  local app_state = global_state.get_app_state()
  if not app_state then
    return nil
  end

  local win = global_state.get_window()
  if not win then
    return nil
  end

  -- Get cursor position (1-indexed, no header in content)
  local row = window.get_cursor(win)
  local cursor_idx = row

  local filtered = app.get_filtered_resources(app_state)
  if cursor_idx < 1 or cursor_idx > #filtered then
    return nil
  end

  return filtered[cursor_idx]
end

---Check if current resource supports the given action
---@param action string
---@return boolean
function M.is_resource_capability_allowed(action)
  local capability = action_to_capability[action]
  if not capability then
    -- Action doesn't require capability check
    return true
  end

  local resource = get_current_resource()
  if not resource then
    return false
  end

  local resource_mod = require("k8s.core.resource")
  local caps = resource_mod.capabilities(resource.kind)
  return caps[capability] == true
end

---Get footer keymaps for a specific view, filtered by resource capability
---@param view_type string
---@param kind? string Resource kind for capability filtering
---@return table[]
function M.get_footer_keymaps(view_type, kind)
  local base_keymaps = footer_keymaps[view_type] or footer_keymaps.list
  local definitions = build_keymap_definitions()

  -- Build keymaps with descriptions from config
  local keymaps = {}
  for _, km in ipairs(base_keymaps) do
    local def = definitions[km.action]
    local desc = def and def.desc or km.action
    table.insert(keymaps, { key = km.key, action = desc })
  end

  -- If no kind specified, return all keymaps
  if not kind then
    return keymaps
  end

  -- Filter keymaps based on resource capabilities
  local resource_mod = require("k8s.core.resource")
  local caps = resource_mod.capabilities(kind)

  local filtered = {}
  for i, km in ipairs(keymaps) do
    local original = base_keymaps[i]
    local capability = action_to_capability[original.action]
    -- Include keymap if action doesn't require capability OR resource has the capability
    if not capability or caps[capability] == true then
      table.insert(filtered, km)
    end
  end

  return filtered
end

---Setup keymaps for a specific window
---@param win K8sWindow
---@param handlers table Action handler functions
function M.setup_keymaps_for_window(win, handlers)
  local window = require("k8s.ui.nui.window")
  local keymaps = M.get_keymap_definitions()

  -- quit/hide (always allowed)
  window.map_key(win, keymaps.quit.key, function()
    handlers.hide()
  end, { desc = keymaps.quit.desc })

  -- close (always allowed)
  window.map_key(win, keymaps.close.key, function()
    handlers.close()
  end, { desc = keymaps.close.desc })

  -- back (always allowed)
  window.map_key(win, keymaps.back.key, function()
    handlers.handle_back()
  end, { desc = keymaps.back.desc })

  -- describe
  window.map_key(win, keymaps.describe.key, function()
    if M.is_action_allowed("describe") then
      handlers.handle_describe()
    end
  end, { desc = keymaps.describe.desc })

  -- select (Enter key)
  window.map_key(win, keymaps.select.key, function()
    if M.is_action_allowed("select") then
      handlers.handle_describe()
    end
  end, { desc = keymaps.select.desc })

  -- refresh
  window.map_key(win, keymaps.refresh.key, function()
    if M.is_action_allowed("refresh") then
      handlers.handle_refresh()
    end
  end, { desc = keymaps.refresh.desc })

  -- filter
  window.map_key(win, keymaps.filter.key, function()
    if M.is_action_allowed("filter") then
      handlers.handle_filter()
    end
  end, { desc = keymaps.filter.desc })

  -- delete (D key) - different behavior per view
  window.map_key(win, keymaps.delete.key, function()
    local view_type = M.get_current_view_type()
    if view_type == "port_forward_list" then
      if M.is_action_allowed("stop") then
        handlers.handle_stop_port_forward()
      end
    elseif M.is_action_allowed("delete") then
      handlers.handle_delete()
    end
  end, { desc = keymaps.delete.desc })

  -- logs
  window.map_key(win, keymaps.logs.key, function()
    if M.is_action_allowed("logs") and M.is_resource_capability_allowed("logs") then
      handlers.handle_logs()
    end
  end, { desc = keymaps.logs.desc })

  -- exec
  window.map_key(win, keymaps.exec.key, function()
    if M.is_action_allowed("exec") and M.is_resource_capability_allowed("exec") then
      handlers.handle_exec()
    end
  end, { desc = keymaps.exec.desc })

  -- scale
  window.map_key(win, keymaps.scale.key, function()
    if M.is_action_allowed("scale") and M.is_resource_capability_allowed("scale") then
      handlers.handle_scale()
    end
  end, { desc = keymaps.scale.desc })

  -- restart
  window.map_key(win, keymaps.restart.key, function()
    if M.is_action_allowed("restart") and M.is_resource_capability_allowed("restart") then
      handlers.handle_restart()
    end
  end, { desc = keymaps.restart.desc })

  -- port_forward
  window.map_key(win, keymaps.port_forward.key, function()
    if M.is_action_allowed("port_forward") and M.is_resource_capability_allowed("port_forward") then
      handlers.handle_port_forward()
    end
  end, { desc = keymaps.port_forward.desc })

  -- port_forward_list
  window.map_key(win, keymaps.port_forward_list.key, function()
    if M.is_action_allowed("port_forward_list") then
      handlers.handle_port_forward_list()
    end
  end, { desc = keymaps.port_forward_list.desc })

  -- resource_menu
  window.map_key(win, keymaps.resource_menu.key, function()
    if M.is_action_allowed("resource_menu") then
      handlers.handle_resource_menu()
    end
  end, { desc = keymaps.resource_menu.desc })

  -- context_menu
  window.map_key(win, keymaps.context_menu.key, function()
    if M.is_action_allowed("context_menu") then
      handlers.handle_context_menu()
    end
  end, { desc = keymaps.context_menu.desc })

  -- namespace_menu
  window.map_key(win, keymaps.namespace_menu.key, function()
    if M.is_action_allowed("namespace_menu") then
      handlers.handle_namespace_menu()
    end
  end, { desc = keymaps.namespace_menu.desc })

  -- logs_previous
  window.map_key(win, keymaps.logs_previous.key, function()
    if M.is_action_allowed("logs_previous") and M.is_resource_capability_allowed("logs_previous") then
      handlers.handle_logs_previous()
    end
  end, { desc = keymaps.logs_previous.desc })

  -- toggle_secret
  window.map_key(win, keymaps.toggle_secret.key, function()
    if M.is_action_allowed("toggle_secret") then
      handlers.handle_toggle_secret()
    end
  end, { desc = keymaps.toggle_secret.desc })

  -- help
  window.map_key(win, keymaps.help.key, function()
    if M.is_action_allowed("help") then
      handlers.handle_help()
    end
  end, { desc = keymaps.help.desc })
end

return M
