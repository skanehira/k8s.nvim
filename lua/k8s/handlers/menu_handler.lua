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
  local global_state = require("k8s.app.global_state")
  local menu_actions = require("k8s.handlers.menu_actions")
  local view_stack = require("k8s.app.view_stack")
  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")
  local app = require("k8s.app.app")

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
        -- Save previous window reference
        local prev_window = global_state.get_window()
        app_state = global_state.get_app_state()

        -- Create new list view window (not mounted yet)
        local new_list_window = window.create_list_view({
          transparent = config and config.transparent,
        })

        -- Write content to buffers BEFORE mount (to avoid flicker)
        local header_bufnr = window.get_header_bufnr(new_list_window)
        if header_bufnr then
          local header_content = buffer.create_header_content({
            context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
            namespace = app_state.current_namespace,
            view = item.value .. "s",
            loading = true,
          })
          window.set_lines(header_bufnr, { header_content })
        end

        local table_header_bufnr = window.get_table_header_bufnr(new_list_window)
        if table_header_bufnr then
          window.set_lines(table_header_bufnr, { "" })
        end

        local content_bufnr = window.get_content_bufnr(new_list_window)
        if content_bufnr then
          window.set_lines(content_bufnr, { "Loading..." })
        end

        local footer_bufnr = window.get_footer_bufnr(new_list_window)
        if footer_bufnr then
          local keymaps = callbacks.get_footer_keymaps("list", item.value)
          local footer_content = buffer.create_footer_content(keymaps)
          window.set_lines(footer_bufnr, { footer_content })
        end

        -- Now mount the window with content already filled
        window.mount(new_list_window)

        -- Setup keymaps on new window
        callbacks.setup_keymaps_for_window(new_list_window)

        -- Update global window reference
        global_state.set_window(new_list_window)

        -- Push new list view to stack with new window
        local vs = global_state.get_view_stack()
        global_state.set_view_stack(view_stack.push(vs, {
          type = "list",
          kind = item.value,
          namespace = app_state.current_namespace,
          parent_cursor = cursor_row,
          window = new_list_window,
        }))

        -- Hide previous window after new window is shown (to avoid flicker)
        if prev_window then
          window.hide(prev_window)
        end

        global_state.set_app_state(app.set_kind(app_state, item.value))
        callbacks.fetch_and_render(item.value, app_state.current_namespace)
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
  local notify = require("k8s.api.notify")

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
  local global_state = require("k8s.app.global_state")
  local adapter = require("k8s.infra.kubectl.adapter")
  local menu_actions = require("k8s.handlers.menu_actions")
  local app = require("k8s.app.app")
  local notify = require("k8s.api.notify")

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
  local global_state = require("k8s.app.global_state")
  local window = require("k8s.ui.nui.window")
  local help = require("k8s.ui.views.help")
  local view_stack = require("k8s.app.view_stack")
  local resource_mod = require("k8s.domain.resources.resource")
  local buffer = require("k8s.ui.nui.buffer")
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

  -- Save current cursor position and window reference
  local cursor_row = 1
  local prev_window = win
  if win then
    cursor_row = window.get_cursor(win)
  end

  -- Create new detail view window (no table_header needed for help)
  local help_window = window.create_detail_view({
    transparent = config and config.transparent,
  })
  window.mount(help_window)

  -- Setup keymaps on new window
  callbacks.setup_keymaps_for_window(help_window)

  -- Update global window reference
  global_state.set_window(help_window)

  -- Push help view to stack with window reference
  local vs = global_state.get_view_stack() or {}
  global_state.set_view_stack(view_stack.push(vs, {
    type = "help",
    parent_view = current_view,
    parent_cursor = cursor_row,
    window = help_window,
  }))

  -- Hide previous window after new window is shown (to avoid flicker)
  if prev_window then
    window.hide(prev_window)
  end

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

  -- Render help content directly
  local content_bufnr = window.get_content_bufnr(help_window)
  if content_bufnr then
    window.set_lines(content_bufnr, help_lines)
    window.set_cursor(help_window, 1, 0)
  end

  -- Update header
  local header_bufnr = window.get_header_bufnr(help_window)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = app_state and app_state.current_namespace or "",
      view = "Help",
    })
    window.set_lines(header_bufnr, { header_content })
  end

  -- Update footer
  callbacks.render_footer("help")
end

return M
