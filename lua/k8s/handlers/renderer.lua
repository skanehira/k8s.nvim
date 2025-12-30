--- renderer.lua - レンダリング関連の処理

local M = {}

---Render footer with keymaps
---@param view_type string
---@param kind? string Resource kind for capability filtering
function M.render_footer(view_type, kind)
  local global_state = require("k8s.app.global_state")
  local window = require("k8s.ui.nui.window")
  local buffer = require("k8s.ui.nui.buffer")
  local keymap = require("k8s.handlers.keymap")

  local win = global_state.get_window()
  if not win then
    return
  end

  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local keymaps = keymap.get_footer_keymaps(view_type, kind)
    local footer_content = buffer.create_footer_content(keymaps)
    window.set_lines(footer_bufnr, { footer_content })
  end
end

---Fetch resources and render
---@param kind string
---@param namespace string
---@param opts? { preserve_cursor?: boolean, restore_cursor?: number }
function M.fetch_and_render(kind, namespace, opts)
  opts = opts or {}
  local global_state = require("k8s.app.global_state")
  local window = require("k8s.ui.nui.window")
  local app = require("k8s.app.app")
  local buffer = require("k8s.ui.nui.buffer")
  local adapter = require("k8s.infra.kubectl.adapter")
  local resource_list_view = require("k8s.ui.views.resource_list")

  local win = global_state.get_window()

  -- Save current cursor position before refresh
  local saved_cursor_row = nil
  if opts.restore_cursor then
    saved_cursor_row = opts.restore_cursor
  elseif opts.preserve_cursor and win then
    saved_cursor_row = window.get_cursor(win)
  end

  -- Show loading indicator in header
  if win and window.is_mounted(win) then
    local header_bufnr = window.get_header_bufnr(win)
    if header_bufnr then
      local header_content = buffer.create_header_content({
        context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
        namespace = namespace,
        view = kind .. "s",
        loading = true,
      })
      window.set_lines(header_bufnr, { header_content })
    end
  end

  adapter.get_resources(kind, namespace, function(result)
    vim.schedule(function()
      win = global_state.get_window()
      if not win or not window.is_mounted(win) then
        return
      end

      -- Update header (remove loading)
      local header_bufnr = window.get_header_bufnr(win)
      if header_bufnr then
        local header_content = buffer.create_header_content({
          context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
          namespace = namespace,
          view = kind .. "s",
        })
        window.set_lines(header_bufnr, { header_content })
      end

      local content_bufnr = window.get_content_bufnr(win)
      if not content_bufnr then
        return
      end

      if not result.ok then
        local error_lines = vim.split("Error: " .. (result.error or "Unknown error"), "\n")
        window.set_lines(content_bufnr, error_lines)
        return
      end

      -- Update app state
      local app_state = global_state.get_app_state()
      global_state.set_app_state(app.set_resources(app_state, result.data))

      -- Get filtered resources (apply current filter)
      app_state = global_state.get_app_state()
      local filtered_resources = app.get_filtered_resources(app_state)

      -- Render table view
      resource_list_view.render(win, {
        resources = filtered_resources,
        kind = kind,
        restore_cursor = saved_cursor_row,
      })

      -- Update footer with capability-filtered keymaps
      M.render_footer("list", kind)
    end)
  end)
end

return M
