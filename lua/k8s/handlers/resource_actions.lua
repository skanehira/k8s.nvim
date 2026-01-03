--- resource_actions.lua - Resource action handlers
--- Handles resource-specific actions like describe, delete, logs, exec, scale, restart, port_forward

local M = {}

---@alias SetupKeymapsCallback fun(win: K8sWindow)

---Toggle secret masking in describe view
function M.toggle_secret()
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
function M.stop_port_forward()
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

---Start port forward
---@param resource table
---@param local_port number
---@param remote_port number
function M.start_port_forward(resource, local_port, remote_port)
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

---Handle port forward action for a resource
---@param resource table
function M.handle_port_forward(resource)
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
      M.start_port_forward(resource, local_port, port.port)
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
      M.start_port_forward(resource, local_port, port.port)
    end)
  end)
end

---Execute action on a specific resource
---@param action string
---@param resource table
---@param setup_keymaps SetupKeymapsCallback
function M.execute(action, resource, setup_keymaps)
  local adapter = require("k8s.adapters.kubectl.adapter")
  local notify = require("k8s.handlers.notify")
  local describe_view = require("k8s.views.describe")
  local lifecycle = require("k8s.handlers.lifecycle")
  local actions = require("k8s.handlers.actions")

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
          lifecycle.push_detail_view(view_state, setup_keymaps)
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
    local container = actions.get_default_container(resource)
    if container then
      local tab_name = actions.format_tab_name("logs", name, container)
      adapter.logs(name, container, namespace, { follow = true, tab_name = tab_name })
    end
  elseif action == "logs_previous" then
    local container = actions.get_default_container(resource)
    if container then
      local tab_name = actions.format_tab_name("logs-prev", name, container)
      adapter.logs(name, container, namespace, { previous = true, tab_name = tab_name })
    end
  elseif action == "exec" then
    local container = actions.get_default_container(resource)
    if container then
      local tab_name = actions.format_tab_name("exec", name, container)
      adapter.exec(name, container, namespace, nil, { tab_name = tab_name })
    end
  elseif action == "port_forward" then
    M.handle_port_forward(resource)
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

return M
