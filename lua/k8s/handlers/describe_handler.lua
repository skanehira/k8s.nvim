--- describe_handler.lua - 詳細表示とPod操作ハンドラー

local M = {}

---Render describe content with secret handling
---@param describe_output string Describe output text
---@param secret_data? table Decoded secret data (only for secrets when unmasked)
local function render_describe_with_secrets(describe_output, secret_data)
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local secret_mask = require("k8s.ui.components.secret_mask")

  local current_win = global_state.get_window()
  if not current_win or not window.is_mounted(current_win) then
    return
  end

  local bufnr = window.get_content_bufnr(current_win)
  if not bufnr then
    return
  end

  local lines = vim.split(describe_output, "\n")

  -- Inject actual decoded values if secret_data is provided
  if secret_data then
    lines = secret_mask.inject_secret_values(lines, secret_data)
  end

  window.set_lines(bufnr, lines)
end

---Re-render describe content with current mask state using cached data
---@param current_view table Current view from view_stack
local function re_render_describe_content(current_view)
  local global_state = require("k8s.core.global_state")
  local adapter = require("k8s.infra.kubectl.adapter")

  local resource = current_view.resource
  local cached_describe = current_view.describe_output

  if not cached_describe then
    return
  end

  local app_state = global_state.get_app_state()
  local needs_secret_data = resource.kind == "Secret" and app_state and not app_state.mask_secrets

  if needs_secret_data then
    -- Fetch secret data for actual values
    adapter.get_secret_data(resource.name, resource.namespace, function(secret_result)
      vim.schedule(function()
        local secret_data = secret_result.ok and secret_result.data or nil
        render_describe_with_secrets(cached_describe, secret_data)
      end)
    end)
  else
    render_describe_with_secrets(cached_describe, nil)
  end
end

---Refresh describe view content (for toggle_secret)
function M.refresh_describe_content()
  local global_state = require("k8s.core.global_state")
  local view_stack_mod = require("k8s.core.view_stack")

  local view_stack = global_state.get_view_stack()
  if not view_stack then
    return
  end

  local current_view = view_stack_mod.current(view_stack)
  if not current_view or current_view.type ~= "describe" then
    return
  end

  local resource = current_view.resource
  if not resource or resource.kind ~= "Secret" then
    return
  end

  re_render_describe_content(current_view)
end

---Handle describe action
---@param callbacks table { setup_keymaps_for_window: function, get_footer_keymaps: function }
function M.handle_describe(callbacks)
  local global_state = require("k8s.core.global_state")
  local list_handler = require("k8s.handlers.list_handler")
  local view_helper = require("k8s.handlers.view_helper")
  local adapter = require("k8s.infra.kubectl.adapter")
  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")

  local resource = list_handler.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local config = global_state.get_config()

  view_helper.create_view({
    view_type = "detail",
    transparent = config and config.transparent,
    header = {
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = resource.namespace,
      view = resource.kind .. ": " .. resource.name,
      loading = true,
    },
    footer_view_type = "describe",
    footer_kind = resource.kind,
    view_stack_entry = { type = "describe", resource = resource },
    initial_content = { "Loading..." },
    pre_render = true,
    on_mounted = function()
      local secret_mask = require("k8s.ui.components.secret_mask")

      local function render_content(describe_data, secret_data)
        local current_win = global_state.get_window()
        if not current_win or not window.is_mounted(current_win) then
          return
        end

        local bufnr = window.get_content_bufnr(current_win)
        if not bufnr then
          return
        end

        local lines = vim.split(describe_data, "\n")

        -- Inject actual decoded values if secret_data is provided
        if secret_data then
          lines = secret_mask.inject_secret_values(lines, secret_data)
        end

        window.set_lines(bufnr, lines)

        -- Set filetype for syntax highlighting
        vim.api.nvim_buf_set_option(bufnr, "filetype", "yaml")

        -- Update header (remove loading)
        local hdr_bufnr = window.get_header_bufnr(current_win)
        if hdr_bufnr then
          local header_content = buffer.create_header_content({
            context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
            namespace = resource.namespace,
            view = resource.kind .. ": " .. resource.name,
          })
          window.set_lines(hdr_bufnr, { header_content })
        end

        -- Set cursor to top
        window.set_cursor(current_win, 1, 0)
      end

      -- Fetch describe output asynchronously
      adapter.describe(resource.kind, resource.name, resource.namespace, function(result)
        vim.schedule(function()
          local view_stack_mod = require("k8s.core.view_stack")

          local current_win = global_state.get_window()
          if not current_win or not window.is_mounted(current_win) then
            return
          end

          local bufnr = window.get_content_bufnr(current_win)
          if not bufnr then
            return
          end

          if not result.ok then
            local error_lines = vim.split("Error: " .. (result.error or "Unknown error"), "\n")
            window.set_lines(bufnr, error_lines)
            return
          end

          -- Cache describe output in view_stack entry for toggle_secret
          local view_stack = global_state.get_view_stack()
          local current_view = view_stack_mod.current(view_stack)
          if current_view then
            current_view.describe_output = result.data
          end

          local app_state = global_state.get_app_state()
          local needs_secret_data = resource.kind == "Secret" and app_state and not app_state.mask_secrets

          if needs_secret_data then
            adapter.get_secret_data(resource.name, resource.namespace, function(secret_result)
              vim.schedule(function()
                local secret_data = secret_result.ok and secret_result.data or nil
                render_content(result.data, secret_data)
              end)
            end)
          else
            render_content(result.data, nil)
          end
        end)
      end)
    end,
  }, callbacks)
end

---Handle logs action
function M.handle_logs()
  local list_handler = require("k8s.handlers.list_handler")
  local pod_actions = require("k8s.handlers.pod_actions")
  local adapter = require("k8s.infra.kubectl.adapter")

  local resource = list_handler.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Logs are only available for Pods", vim.log.levels.WARN)
    return
  end

  -- Get containers for selection
  local containers = pod_actions.get_containers(resource)
  if not containers or #containers == 0 then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  local function open_logs(container)
    -- Open in new tab
    vim.cmd("tabnew")

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

  -- If single container, open directly
  if #containers == 1 then
    open_logs(containers[1])
    return
  end

  -- Multiple containers - show selection menu
  vim.ui.select(containers, {
    prompt = "Select Container:",
  }, function(choice)
    if choice then
      open_logs(choice)
    end
  end)
end

---Handle logs_previous action (previous container logs with -p)
function M.handle_logs_previous()
  local list_handler = require("k8s.handlers.list_handler")
  local pod_actions = require("k8s.handlers.pod_actions")
  local adapter = require("k8s.infra.kubectl.adapter")

  local resource = list_handler.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Previous logs are only available for Pods", vim.log.levels.WARN)
    return
  end

  -- Get containers for selection
  local containers = pod_actions.get_containers(resource)
  if not containers or #containers == 0 then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  local function open_previous_logs(container)
    -- Open in new tab
    vim.cmd("tabnew")

    local result = adapter.logs(resource.name, container, resource.namespace, {
      follow = false,
      timestamps = true,
      previous = true,
    })

    if not result.ok then
      vim.notify("Failed to open previous logs: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Set tab name
    local tab_name = pod_actions.format_tab_name("logs-prev", resource.name, container)
    vim.api.nvim_buf_set_name(0, tab_name)
  end

  -- If single container, open directly
  if #containers == 1 then
    open_previous_logs(containers[1])
    return
  end

  -- Multiple containers - show selection menu
  vim.ui.select(containers, {
    prompt = "Select Container:",
  }, function(choice)
    if choice then
      open_previous_logs(choice)
    end
  end)
end

---Handle exec action
function M.handle_exec()
  local list_handler = require("k8s.handlers.list_handler")
  local pod_actions = require("k8s.handlers.pod_actions")
  local adapter = require("k8s.infra.kubectl.adapter")

  local resource = list_handler.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  if not pod_actions.validate_pod_action(resource.kind) then
    vim.notify("Exec is only available for Pods", vim.log.levels.WARN)
    return
  end

  -- Get containers for selection
  local containers = pod_actions.get_containers(resource)
  if not containers or #containers == 0 then
    vim.notify("No container found", vim.log.levels.WARN)
    return
  end

  local function open_exec(container)
    -- Open in new tab
    vim.cmd("tabnew")

    -- Capture current buffer for auto-close
    local bufnr = vim.api.nvim_get_current_buf()

    local result = adapter.exec(resource.name, container, resource.namespace, nil, {
      on_exit = function()
        -- Auto-close tab when shell exits
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            -- Close the buffer (this will close the tab if it's the only buffer)
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end
        end)
      end,
    })

    if not result.ok then
      vim.notify("Failed to exec: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Set tab name
    local tab_name = pod_actions.format_tab_name("exec", resource.name, container)
    vim.api.nvim_buf_set_name(0, tab_name)
  end

  -- If single container, open directly
  if #containers == 1 then
    open_exec(containers[1])
    return
  end

  -- Multiple containers - show selection menu
  vim.ui.select(containers, {
    prompt = "Select Container:",
  }, function(choice)
    if choice then
      open_exec(choice)
    end
  end)
end

return M
