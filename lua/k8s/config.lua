--- config.lua - 設定管理

local M = {}

-- =============================================================================
-- Keymap Templates
-- =============================================================================

-- Common keymaps shared by all list views
local list_common = {
  select = { key = "<CR>", desc = "Select" },
  describe = { key = "d", desc = "Describe" },
  filter = { key = "<C-f>", desc = "Filter" },
  refresh = { key = "r", desc = "Refresh" },
  resource_menu = { key = "<C-r>", desc = "Resources" },
  context_menu = { key = "C", desc = "Context" },
  namespace_menu = { key = "N", desc = "Namespace" },
  port_forward_list = { key = "F", desc = "PortFwdList" },
}

-- Resource-specific actions
local actions = {
  delete = { key = "D", desc = "Delete" },
  logs = { key = "l", desc = "Logs" },
  logs_previous = { key = "P", desc = "PrevLogs" },
  exec = { key = "e", desc = "Exec" },
  scale = { key = "s", desc = "Scale" },
  restart = { key = "X", desc = "Restart" },
  port_forward = { key = "p", desc = "PortFwd" },
  show_events = { key = "E", desc = "Events" },
  debug = { key = "<leader>d", desc = "Debug" },
}

---Merge common keymaps with resource-specific ones
---@param ... table
---@return table
local function merge_keymaps(...)
  local result = {}
  for _, t in ipairs({ ... }) do
    for k, v in pairs(t) do
      result[k] = v
    end
  end
  return result
end

-- =============================================================================
-- Default Keymaps Definition
-- =============================================================================

local default_keymaps = {
  -- Global keymaps (shared across all views)
  global = {
    quit = { key = "q", desc = "Hide" },
    close = { key = "<C-c>", desc = "Close" },
    back = { key = "<C-h>", desc = "Back" },
    forward = { key = "<C-l>", desc = "Forward" },
    help = { key = "?", desc = "Help" },
  },

  -- =============================================================================
  -- List Views (per resource kind)
  -- =============================================================================

  -- Pod: logs, exec, port_forward, delete, debug, show_events
  pod_list = merge_keymaps(list_common, {
    delete = actions.delete,
    logs = actions.logs,
    logs_previous = actions.logs_previous,
    exec = actions.exec,
    port_forward = actions.port_forward,
    show_events = actions.show_events,
    debug = actions.debug,
  }),

  -- Deployment: scale, restart, port_forward, delete
  deployment_list = merge_keymaps(list_common, {
    delete = actions.delete,
    scale = actions.scale,
    restart = actions.restart,
    port_forward = actions.port_forward,
  }),

  -- ReplicaSet: scale, delete
  replicaset_list = merge_keymaps(list_common, {
    delete = actions.delete,
    scale = actions.scale,
  }),

  -- StatefulSet: scale, restart, port_forward, delete
  statefulset_list = merge_keymaps(list_common, {
    delete = actions.delete,
    scale = actions.scale,
    restart = actions.restart,
    port_forward = actions.port_forward,
  }),

  -- DaemonSet: restart, port_forward, delete
  daemonset_list = merge_keymaps(list_common, {
    delete = actions.delete,
    restart = actions.restart,
    port_forward = actions.port_forward,
  }),

  -- Job: logs, delete
  job_list = merge_keymaps(list_common, {
    delete = actions.delete,
    logs = actions.logs,
    logs_previous = actions.logs_previous,
  }),

  -- CronJob: delete
  cronjob_list = merge_keymaps(list_common, {
    delete = actions.delete,
  }),

  -- Service: port_forward, delete
  service_list = merge_keymaps(list_common, {
    delete = actions.delete,
    port_forward = actions.port_forward,
  }),

  -- ConfigMap: delete
  configmap_list = merge_keymaps(list_common, {
    delete = actions.delete,
  }),

  -- Secret: delete
  secret_list = merge_keymaps(list_common, {
    delete = actions.delete,
  }),

  -- Node: (no delete, no special actions)
  node_list = merge_keymaps(list_common, {}),

  -- Namespace: delete
  namespace_list = merge_keymaps(list_common, {
    delete = actions.delete,
  }),

  -- Ingress: delete
  ingress_list = merge_keymaps(list_common, {
    delete = actions.delete,
  }),

  -- Event: (no delete, no special actions)
  event_list = merge_keymaps(list_common, {}),

  -- Application (ArgoCD): (no delete, no special actions)
  application_list = merge_keymaps(list_common, {}),

  -- =============================================================================
  -- Describe Views
  -- =============================================================================

  -- Common describe view (no special actions)
  describe = {},

  -- Secret describe: toggle mask
  secret_describe = {
    toggle_secret = { key = "S", desc = "ToggleSecret" },
  },

  -- =============================================================================
  -- Special Views
  -- =============================================================================

  -- Port forward list view
  port_forward_list = {
    stop = { key = "D", desc = "Stop" },
  },

  -- Help view (only navigation, no help key)
  help = {},
}

-- Default configuration
local defaults = {
  timeout = 30000, -- 30 seconds
  default_namespace = "default",
  default_kind = "Pod",
  transparent = false, -- Transparent window background
  debug_image = "busybox", -- Debug container image for kubectl debug
  keymaps = default_keymaps,
}

---Get default configuration
---@return table
function M.get_defaults()
  return vim.deepcopy(defaults)
end

---Deep merge two tables
---@param t1 table
---@param t2 table
---@return table
local function deep_merge(t1, t2)
  local result = vim.deepcopy(t1)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

---Merge user config with defaults
---@param user_config table|nil
---@return table
function M.merge(user_config)
  if not user_config then
    return M.get_defaults()
  end
  return deep_merge(M.get_defaults(), user_config)
end

---Validate configuration
---@param cfg table
---@return boolean valid
---@return string|nil error
function M.validate(cfg)
  if type(cfg.timeout) ~= "number" or cfg.timeout < 1000 then
    return false, "timeout must be a number >= 1000"
  end

  return true, nil
end

return M
