--- port_forward_handler.lua - ポートフォワード関連ハンドラー

local M = {}

---Prompt for custom port forward (when no auto-detected ports)
---@param callback function(local_port: number, remote_port: number)
function M.prompt_custom_port_forward(callback)
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

---Handle port forward action
function M.handle_port_forward()
  local list_handler = require("k8s.handlers.list_handler")
  local resource_mod = require("k8s.domain.resources.resource")
  local pod_actions = require("k8s.handlers.pod_actions")
  local adapter = require("k8s.infra.kubectl.adapter")
  local connections = require("k8s.domain.state.connections")
  local notify = require("k8s.api.notify")

  local resource = list_handler.get_current_resource()
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
    local result = adapter.port_forward(resource_name, resource.namespace, local_port, remote_port)

    if result.ok then
      connections.add({
        job_id = result.data.job_id,
        resource = resource_name,
        namespace = resource.namespace,
        local_port = local_port,
        remote_port = remote_port,
      })

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
        M.prompt_custom_port_forward(start_port_forward)
      end
    end)
  else
    -- No ports defined, prompt manually
    M.prompt_custom_port_forward(start_port_forward)
  end
end

---Handle port forward list action
---@param callbacks table { setup_keymaps_for_window: function, render_footer: function }
function M.handle_port_forward_list(callbacks)
  local global_state = require("k8s.app.global_state")
  local window = require("k8s.ui.nui.window")
  local view_stack = require("k8s.app.view_stack")
  local connections = require("k8s.domain.state.connections")
  local port_forward_list = require("k8s.ui.views.port_forward_list")
  local buffer = require("k8s.ui.nui.buffer")

  local win = global_state.get_window()
  if not win then
    return
  end

  local config = global_state.get_config()

  -- Save current cursor position and window reference
  local cursor_row = 1
  local prev_window = win
  if win then
    cursor_row = window.get_cursor(win)
  end

  -- Create new detail view window (no table_header needed for port forward list)
  local pf_window = window.create_detail_view({
    transparent = config and config.transparent,
  })
  window.mount(pf_window)

  -- Setup keymaps on new window
  callbacks.setup_keymaps_for_window(pf_window)

  -- Update global window reference
  global_state.set_window(pf_window)

  -- Push port forward list view to stack with window reference
  local vs = global_state.get_view_stack()
  global_state.set_view_stack(view_stack.push(vs, {
    type = "port_forward_list",
    parent_cursor = cursor_row,
    window = pf_window,
  }))

  -- Hide previous window after new window is shown (to avoid flicker)
  if prev_window then
    window.hide(prev_window)
  end

  -- Get active connections
  local active = connections.get_all()

  -- Store connections reference for stop action
  global_state.set_pf_list_connections(active)

  -- Render port forward list content directly
  local content_bufnr = window.get_content_bufnr(pf_window)
  if content_bufnr then
    local lines = port_forward_list.create_content(active)
    window.set_lines(content_bufnr, lines)

    -- Set cursor to first data row if connections exist
    if active and #active > 0 then
      window.set_cursor(pf_window, 2, 0) -- After header row
    else
      window.set_cursor(pf_window, 1, 0)
    end
  end

  -- Update header
  local header_bufnr = window.get_header_bufnr(pf_window)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = "",
      view = "Port Forwards",
    })
    window.set_lines(header_bufnr, { header_content })
  end

  -- Update footer
  callbacks.render_footer("port_forward_list")
end

---Handle stop port forward action (D key in port forward list view)
---@param callbacks table { handle_port_forward_list: function }
function M.handle_stop_port_forward(callbacks)
  local global_state = require("k8s.app.global_state")
  local view_stack_mod = require("k8s.app.view_stack")
  local window = require("k8s.ui.nui.window")
  local connections = require("k8s.domain.state.connections")
  local notify = require("k8s.api.notify")

  local view_stack = global_state.get_view_stack()
  local current = view_stack_mod.current(view_stack)

  -- Only allow in port_forward_list view
  if not current or current.type ~= "port_forward_list" then
    return
  end

  local pf_connections = global_state.get_pf_list_connections()
  if not pf_connections or #pf_connections == 0 then
    vim.notify("No active port forwards", vim.log.levels.INFO)
    return
  end

  local win = global_state.get_window()
  if not win then
    return
  end

  -- Get cursor position (1-indexed, row 1 is header)
  local row = window.get_cursor(win)
  local cursor_idx = row - 1

  if cursor_idx < 1 or cursor_idx > #pf_connections then
    vim.notify("No port forward selected", vim.log.levels.WARN)
    return
  end

  local conn = pf_connections[cursor_idx]
  if not conn then
    return
  end

  -- Stop the port forward job
  pcall(vim.fn.jobstop, conn.job_id)

  -- Remove from connections
  connections.remove(conn.job_id)

  -- Notify user
  local msg = notify.format_port_forward_message(conn.resource, conn.local_port, conn.remote_port, "stop")
  vim.notify(msg, vim.log.levels.INFO)

  -- Refresh the port forward list view
  callbacks.handle_port_forward_list()
end

return M
