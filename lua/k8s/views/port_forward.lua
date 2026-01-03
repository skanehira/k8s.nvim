--- port_forward.lua - ポートフォワード一覧ビュー
--- Lifecycle: on_mounted (なし), on_unmounted (なし), render (接続一覧表示)

local M = {}

local buffer = require("k8s.ui.nui.buffer")
local keymaps = require("k8s.views.keymaps")

-- =============================================================================
-- View Factory
-- =============================================================================

---Create a port forward list view with lifecycle callbacks
---@param opts? { window?: table }
---@return ViewState
function M.create_view(opts)
  opts = opts or {}
  local view_module = require("k8s.state.view")

  -- Create view state with lifecycle callbacks
  local view_state = view_module.create_list_state("port_forward_list", {
    window = opts.window,
    on_mounted = function(view)
      M._on_mounted(view)
    end,
    on_unmounted = function(view)
      M._on_unmounted(view)
    end,
    render = function(view, win)
      M._render(view, win)
    end,
  })

  return view_state
end

---Called when view is mounted (shown)
---@param _ ViewState (unused, but required for lifecycle interface)
function M._on_mounted(_)
  -- Port forward list doesn't need watcher
  local state = require("k8s.state")
  state.notify()
end

---Called when view is unmounted (hidden)
---@param _ ViewState (unused, but required for lifecycle interface)
function M._on_unmounted(_)
  -- No cleanup needed for port forward list
end

---Render the port forward list view
---@param _ ViewState (unused, connections are global)
---@param win table Window reference
function M._render(_, win)
  local window = require("k8s.ui.nui.window")
  local state = require("k8s.state")
  local connections = require("k8s.handlers.connections")

  if not win or not window.is_mounted(win) then
    return
  end

  -- Show table header for port forward list
  window.show_table_header(win)

  -- Update header
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = state.get_namespace(),
      view = "Port Forwards",
    })
    window.set_lines(header_bufnr, { header_content })
  end

  -- Set table header
  local table_header_bufnr = window.get_table_header_bufnr(win)
  if table_header_bufnr then
    window.set_lines(table_header_bufnr, { string.format("%-30s %-15s %-20s", "RESOURCE", "NAMESPACE", "PORTS") })
  end

  -- Render connections
  local content_bufnr = window.get_content_bufnr(win)
  if content_bufnr then
    local all_connections = connections.get_all()
    local lines = {}

    for _, conn in ipairs(all_connections) do
      local ports = string.format("%d:%d", conn.local_port or 0, conn.remote_port or 0)
      table.insert(lines, string.format("%-30s %-15s %-20s", conn.resource or "", conn.namespace or "", ports))
    end

    window.set_lines(content_bufnr, lines)
  end

  -- Update footer
  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local footer_keymaps = keymaps.get_footer_keymaps("port_forward_list")
    local footer_content = buffer.create_footer_content(footer_keymaps)
    window.set_lines(footer_bufnr, { footer_content })
  end
end

return M
