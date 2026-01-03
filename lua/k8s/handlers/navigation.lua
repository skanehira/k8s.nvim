--- navigation.lua - Navigation menu handlers
--- Handles help, resource, context, and namespace menus

local M = {}

---Show help view
---@param setup_keymaps SetupKeymapsCallback
function M.show_help(setup_keymaps)
  local state = require("k8s.state")
  local help = require("k8s.views.help")
  local lifecycle = require("k8s.handlers.lifecycle")

  local current_view = state.get_current_view()
  if not current_view then
    return
  end

  -- Create help view using factory
  local view_state = help.create_view(current_view.type)

  -- Push help view with new detail window
  lifecycle.push_detail_view(view_state, setup_keymaps)
end

---Show resource menu
---@param setup_keymaps SetupKeymapsCallback
function M.show_resource_menu(setup_keymaps)
  local state = require("k8s.state")
  local actions = require("k8s.handlers.actions")
  local window = require("k8s.ui.nui.window")
  local list_view = require("k8s.views.list")
  local lifecycle = require("k8s.handlers.lifecycle")
  local render = require("k8s.handlers.render")

  local items = actions.get_resource_menu_items()
  local options = {}
  for _, item in ipairs(items) do
    table.insert(options, item.text)
  end

  vim.ui.select(options, {
    prompt = actions.get_menu_title("resource"),
  }, function(choice)
    if not choice then
      return
    end

    for _, item in ipairs(items) do
      if item.text == choice then
        local kind = item.value
        local view_type = kind:lower() .. "_list"

        -- Check if switching to same resource type
        local current_view = state.get_current_view()
        if current_view and current_view.type == view_type then
          return
        end

        -- Create new list view window
        local config = state.get_config() or {}
        local new_win = window.create_list_view({ transparent = config.transparent })
        window.mount(new_win)

        -- Create view state using factory (namespace is taken from state in on_mounted)
        local view_state = list_view.create_view(kind, {
          window = new_win,
        })

        -- Use lifecycle-aware push
        lifecycle.push_view(view_state, setup_keymaps)

        -- Render immediately
        render.render()
        break
      end
    end
  end)
end

---Show context menu
function M.show_context_menu()
  local adapter = require("k8s.adapters.kubectl.adapter")
  local actions = require("k8s.handlers.actions")
  local notify = require("k8s.handlers.notify")
  local watcher = require("k8s.handlers.watcher")
  local state = require("k8s.state")

  adapter.get_contexts(function(result)
    vim.schedule(function()
      if not result.ok then
        notify.error("Failed to get contexts: " .. (result.error or "Unknown error"))
        return
      end

      vim.ui.select(result.data, {
        prompt = actions.get_menu_title("context"),
      }, function(choice)
        if not choice then
          return
        end

        adapter.use_context(choice, function(switch_result)
          vim.schedule(function()
            if switch_result.ok then
              state.set_context(choice)
              notify.info("Switched to context: " .. choice)

              -- Refresh resources for new context
              state.clear_resources()
              watcher.restart({})
            else
              notify.error("Failed to switch context: " .. (switch_result.error or "Unknown error"))
            end
          end)
        end)
      end)
    end)
  end)
end

---Show namespace menu
function M.show_namespace_menu()
  local adapter = require("k8s.adapters.kubectl.adapter")
  local actions = require("k8s.handlers.actions")
  local notify = require("k8s.handlers.notify")
  local watcher = require("k8s.handlers.watcher")
  local state = require("k8s.state")

  adapter.get_namespaces(function(result)
    vim.schedule(function()
      if not result.ok then
        notify.error("Failed to get namespaces: " .. (result.error or "Unknown error"))
        return
      end

      -- Add "All Namespaces" option at the beginning
      local options = { "All Namespaces" }
      for _, ns in ipairs(result.data) do
        table.insert(options, ns)
      end

      vim.ui.select(options, {
        prompt = actions.get_menu_title("namespace"),
      }, function(choice)
        if not choice then
          return
        end

        state.set_namespace(choice)
        notify.info("Switched to namespace: " .. choice)

        -- Restart watcher with new namespace
        watcher.restart({})
      end)
    end)
  end)
end

return M
