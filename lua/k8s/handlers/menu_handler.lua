--- menu_handler.lua - メニュー表示とヘルプハンドラー

local M = {}

-- Map help action names to capability names
local help_action_to_capability = {
  Logs = "logs",
  PrevLogs = "logs",
  Exec = "exec",
  Scale = "scale",
  Restart = "restart",
  PortFwd = "port_forward",
}

---Handle resource menu action
---@param callbacks table { setup_keymaps_for_window: function, get_footer_keymaps: function, fetch_and_render: function }
function M.handle_resource_menu(callbacks)
  local global_state = require("k8s.core.global_state")
  local menu_actions = require("k8s.handlers.menu_actions")
  local view_helper = require("k8s.handlers.view_helper")
  local window = require("k8s.ui.nui.window")
  local app = require("k8s.core.state")

  local config = global_state.get_config()
  local win = global_state.get_window()
  local app_state = global_state.get_app_state()

  -- Save current cursor position before showing menu
  local cursor_row = 1
  if win then
    cursor_row = window.get_cursor(win)
  end

  local items = menu_actions.get_resource_menu_items()
  local options = {}
  for _, item in ipairs(items) do
    table.insert(options, item.text)
  end

  vim.ui.select(options, {
    prompt = menu_actions.get_menu_title("resource"),
  }, function(choice)
    if not choice then
      return
    end

    for _, item in ipairs(items) do
      if item.text == choice then
        app_state = global_state.get_app_state()

        view_helper.create_view({
          view_type = "list",
          transparent = config and config.transparent,
          header = {
            context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
            namespace = app_state.current_namespace,
            view = item.value .. "s",
            loading = true,
          },
          footer_view_type = "list",
          footer_kind = item.value,
          view_stack_entry = {
            type = "list",
            kind = item.value,
            namespace = app_state.current_namespace,
            parent_cursor = cursor_row,
          },
          initial_content = { "Loading..." },
          pre_render = true,
          on_mounted = function()
            global_state.set_app_state(app.set_kind(app_state, item.value))
            callbacks.fetch_and_render(item.value, app_state.current_namespace)
          end,
        }, callbacks)
        break
      end
    end
  end)
end

---Handle context menu action
---@param callbacks table { handle_refresh: function }
function M.handle_context_menu(callbacks)
  local adapter = require("k8s.infra.kubectl.adapter")
  local menu_actions = require("k8s.handlers.menu_actions")
  local notify = require("k8s.core.notify")

  adapter.get_contexts(function(result)
    vim.schedule(function()
      if not result.ok then
        vim.notify("Failed to get contexts: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
        return
      end

      vim.ui.select(result.data, {
        prompt = menu_actions.get_menu_title("context"),
      }, function(choice)
        if not choice then
          return
        end

        adapter.use_context(choice, function(switch_result)
          vim.schedule(function()
            if switch_result.ok then
              vim.notify(notify.format_context_switch_message(choice), vim.log.levels.INFO)
              callbacks.handle_refresh()
            else
              vim.notify("Failed to switch context: " .. (switch_result.error or "Unknown error"), vim.log.levels.ERROR)
            end
          end)
        end)
      end)
    end)
  end)
end

---Handle namespace menu action
---@param callbacks table { fetch_and_render: function }
function M.handle_namespace_menu(callbacks)
  local global_state = require("k8s.core.global_state")
  local adapter = require("k8s.infra.kubectl.adapter")
  local menu_actions = require("k8s.handlers.menu_actions")
  local app = require("k8s.core.state")
  local notify = require("k8s.core.notify")

  adapter.get_namespaces(function(result)
    vim.schedule(function()
      if not result.ok then
        vim.notify("Failed to get namespaces: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
        return
      end

      -- Add "All Namespaces" option at the beginning
      local options = { "All Namespaces" }
      for _, ns in ipairs(result.data) do
        table.insert(options, ns)
      end

      vim.ui.select(options, {
        prompt = menu_actions.get_menu_title("namespace"),
      }, function(choice)
        if not choice then
          return
        end

        local app_state = global_state.get_app_state()
        local namespace = choice == "All Namespaces" and "" or choice
        global_state.set_app_state(app.set_namespace(app_state, namespace))

        vim.notify(notify.format_namespace_switch_message(choice), vim.log.levels.INFO)

        app_state = global_state.get_app_state()
        callbacks.fetch_and_render(app_state.current_kind, namespace)
      end)
    end)
  end)
end

---Handle help action
---@param callbacks table { setup_keymaps_for_window: function, render_footer: function }
function M.handle_help(callbacks)
  local global_state = require("k8s.core.global_state")
  local view_helper = require("k8s.handlers.view_helper")
  local window = require("k8s.ui.nui.window")
  local help = require("k8s.ui.views.help")
  local resource_mod = require("k8s.core.resource")
  local keymap_mod = require("k8s.handlers.keymap")

  local win = global_state.get_window()
  if not win then
    return
  end

  local config = global_state.get_config()
  local app_state = global_state.get_app_state()

  -- Get current view type before pushing help
  local current_view = keymap_mod.get_current_view_type() or "list"
  -- Map to help.lua view names
  local help_view_name = current_view == "list" and "resource_list" or current_view

  -- Get current resource kind for capability filtering
  local current_kind = app_state and app_state.current_kind

  -- Get keymaps for the current view
  local view_keymaps = help.get_keymaps_for_view(help_view_name)

  -- Filter keymaps based on resource capabilities
  local filtered_keymaps = {}
  if current_kind then
    local caps = resource_mod.capabilities(current_kind)
    for _, km in ipairs(view_keymaps) do
      local capability = help_action_to_capability[km.action]
      -- Include keymap if action doesn't require capability OR resource has the capability
      if not capability or caps[capability] == true then
        table.insert(filtered_keymaps, km)
      end
    end
  else
    filtered_keymaps = view_keymaps
  end

  local help_lines = {}
  table.insert(help_lines, help.get_help_title())
  table.insert(help_lines, "")

  -- Format keymaps
  local keymap_lines = help.format_keymap_lines(filtered_keymaps, 4)
  for _, line in ipairs(keymap_lines) do
    table.insert(help_lines, line)
  end

  view_helper.create_view({
    view_type = "detail",
    transparent = config and config.transparent,
    header = {
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = app_state and app_state.current_namespace or "",
      view = "Help",
    },
    footer_view_type = "help",
    view_stack_entry = {
      type = "help",
      parent_view = current_view,
    },
    initial_content = help_lines,
    pre_render = false,
    on_mounted = function(help_win)
      window.set_cursor(help_win, 1, 0)
    end,
  }, callbacks)
end

return M
