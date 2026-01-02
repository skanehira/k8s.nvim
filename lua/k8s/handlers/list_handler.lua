--- list_handler.lua - リスト表示関連のハンドラー

local M = {}

-- =============================================================================
-- Helper functions
-- =============================================================================

---Get current resource at cursor position
---@return table|nil
function M.get_current_resource()
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

-- =============================================================================
-- Action Handlers
-- =============================================================================

---Handle back action
---@param callbacks table { render_footer: function }
function M.handle_back(callbacks)
  local global_state = require("k8s.core.global_state")
  local view_stack_mod = require("k8s.core.view_stack")
  local window = require("k8s.ui.nui.window")
  local view_restorer = require("k8s.handlers.view_restorer")

  local view_stack = global_state.get_view_stack()
  if not view_stack or not view_stack_mod.can_pop(view_stack) then
    return
  end

  -- Get the current view before popping (to unmount its window)
  local current_view = view_stack_mod.current(view_stack)

  -- Pop returns (new_stack, popped_view)
  local new_stack, popped_view = view_stack_mod.pop(view_stack)
  global_state.set_view_stack(new_stack)

  -- Get cursor position to restore from popped view
  local restore_cursor = popped_view and popped_view.parent_cursor

  -- Get the previous view (now current after pop)
  local prev_view = view_stack_mod.current(new_stack)

  -- Check if current and previous views share the same window
  local same_window = current_view and prev_view and current_view.window == prev_view.window

  if prev_view and prev_view.window then
    -- Show the previous view's window first (only if different window)
    if not same_window then
      window.show(prev_view.window)
    end

    -- Update global window reference
    global_state.set_window(prev_view.window)

    -- Restore view using polymorphic dispatch
    view_restorer.restore(prev_view, callbacks, restore_cursor)

    -- Unmount the current (popped) view's window after showing previous
    if current_view and current_view.window and not same_window then
      window.unmount(current_view.window)
    end
  end
end

---Handle refresh action
---@param callbacks table { start_watcher: function }
function M.handle_refresh(callbacks)
  local global_state = require("k8s.core.global_state")
  local app = require("k8s.core.state")

  local app_state = global_state.get_app_state()
  if not app_state then
    return
  end

  -- Clear resources and restart watcher
  global_state.set_app_state(app.clear_resources(app_state))
  callbacks.start_watcher(app_state.current_kind, app_state.current_namespace)
end

---Handle filter action
---@param callbacks table { render_filtered_resources: function }
function M.handle_filter(callbacks)
  local global_state = require("k8s.core.global_state")
  local app = require("k8s.core.state")

  local app_state = global_state.get_app_state()
  local current_filter = app_state and app_state.filter or ""

  vim.ui.input({ prompt = "Filter: ", default = current_filter }, function(input)
    if input == nil then
      return -- Cancelled
    end

    app_state = global_state.get_app_state()
    if not app_state then
      return
    end

    if input == "" then
      -- Clear filter
      global_state.set_app_state(app.set_filter(app_state, nil))
    else
      global_state.set_app_state(app.set_filter(app_state, input))
    end

    -- Re-render with filter applied
    callbacks.render_filtered_resources()
  end)
end

---Render resources with current filter
function M.render_filtered_resources()
  local global_state = require("k8s.core.global_state")
  local window = require("k8s.ui.nui.window")
  local app = require("k8s.core.state")
  local buffer = require("k8s.ui.nui.buffer")
  local resource_list_view = require("k8s.ui.views.resource_list")

  local win = global_state.get_window()
  local app_state = global_state.get_app_state()
  if not win or not app_state then
    return
  end

  -- Get filtered resources
  local resources = app.get_filtered_resources(app_state)
  local kind = app_state.current_kind

  -- Render table view
  resource_list_view.render(win, {
    resources = resources,
    kind = kind,
  })

  -- Update header to show filter
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = app_state.current_namespace,
      view = kind .. "s",
      filter = app_state.filter,
    })
    window.set_lines(header_bufnr, { header_content })
  end
end

---Handle delete action
---@param callbacks table { handle_refresh: function }
function M.handle_delete(callbacks)
  local resource = M.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local resource_actions = require("k8s.handlers.resource_actions")

  if not resource_actions.validate_delete_target(resource.kind) then
    vim.notify("Cannot delete " .. resource.kind, vim.log.levels.WARN)
    return
  end

  local action = resource_actions.create_delete_action(resource)
  local choice = vim.fn.confirm(action.confirm_message, "&Yes\n&No", 2)

  if choice ~= 1 then
    return
  end

  local adapter = require("k8s.infra.kubectl.adapter")

  adapter.delete(resource.kind, resource.name, resource.namespace, function(result)
    vim.schedule(function()
      if result.ok then
        vim.notify(
          resource_actions.format_action_result("delete", resource.kind, resource.name, true),
          vim.log.levels.INFO
        )
        callbacks.handle_refresh()
      else
        vim.notify(
          resource_actions.format_action_result("delete", resource.kind, resource.name, false, result.error),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

---Handle scale action
---@param callbacks table { handle_refresh: function }
function M.handle_scale(callbacks)
  local resource = M.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local resource_actions = require("k8s.handlers.resource_actions")

  if not resource_actions.validate_scale_target(resource.kind) then
    vim.notify("Cannot scale " .. resource.kind, vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "Replicas: " }, function(input)
    if input == nil or input == "" then
      return
    end

    local replicas = tonumber(input)
    if not replicas or replicas < 0 then
      vim.notify("Invalid replicas number", vim.log.levels.WARN)
      return
    end

    local adapter = require("k8s.infra.kubectl.adapter")

    adapter.scale(resource.kind, resource.name, resource.namespace, replicas, function(result)
      vim.schedule(function()
        if result.ok then
          vim.notify(
            resource_actions.format_action_result("scale", resource.kind, resource.name, true),
            vim.log.levels.INFO
          )
          callbacks.handle_refresh()
        else
          vim.notify(
            resource_actions.format_action_result("scale", resource.kind, resource.name, false, result.error),
            vim.log.levels.ERROR
          )
        end
      end)
    end)
  end)
end

---Handle restart action
---@param callbacks table { handle_refresh: function }
function M.handle_restart(callbacks)
  local resource = M.get_current_resource()
  if not resource then
    vim.notify("No resource selected", vim.log.levels.WARN)
    return
  end

  local resource_actions = require("k8s.handlers.resource_actions")

  if not resource_actions.validate_restart_target(resource.kind) then
    vim.notify("Cannot restart " .. resource.kind, vim.log.levels.WARN)
    return
  end

  local action = resource_actions.create_restart_action(resource)
  local choice = vim.fn.confirm(action.confirm_message, "&Yes\n&No", 2)

  if choice ~= 1 then
    return
  end

  local adapter = require("k8s.infra.kubectl.adapter")

  adapter.restart(resource.kind, resource.name, resource.namespace, function(result)
    vim.schedule(function()
      if result.ok then
        vim.notify(
          resource_actions.format_action_result("restart", resource.kind, resource.name, true),
          vim.log.levels.INFO
        )
        callbacks.handle_refresh()
      else
        vim.notify(
          resource_actions.format_action_result("restart", resource.kind, resource.name, false, result.error),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

---Handle toggle_secret action
---@param callbacks table { render_filtered_resources: function }
function M.handle_toggle_secret(callbacks)
  local global_state = require("k8s.core.global_state")
  local app = require("k8s.core.state")
  local view_stack_mod = require("k8s.core.view_stack")

  local app_state = global_state.get_app_state()
  if not app_state then
    return
  end

  -- Toggle secret mask state
  local current_mask = app_state.mask_secrets
  global_state.set_app_state(app.set_mask_secrets(app_state, not current_mask))

  app_state = global_state.get_app_state()
  assert(app_state, "app_state is nil")
  local status = app_state.mask_secrets and "masked" or "visible"
  vim.notify("Secrets are now " .. status, vim.log.levels.INFO)

  -- Check current view type
  local view_stack = global_state.get_view_stack()
  local current_view = view_stack and view_stack_mod.current(view_stack)

  if current_view and current_view.type == "describe" then
    -- Re-render describe view if viewing a Secret
    local describe_handler = require("k8s.handlers.describe_handler")
    describe_handler.refresh_describe_content()
  elseif app_state.current_kind == "Secret" then
    -- Re-render list if viewing secrets
    callbacks.render_filtered_resources()
  end
end

return M
