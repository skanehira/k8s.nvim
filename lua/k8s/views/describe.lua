--- describe.lua - リソース詳細表示ビュー
--- Lifecycle: on_mounted (なし), on_unmounted (なし), render (describe出力表示)

local M = {}

local buffer = require("k8s.ui.nui.buffer")

-- =============================================================================
-- View Factory
-- =============================================================================

---Create a describe view with lifecycle callbacks
---@param kind K8sResourceKind Resource kind (e.g., "Pod", "Deployment")
---@param resource table Target resource
---@param opts? { window?: table, describe_output?: string }
---@return ViewState
function M.create_view(kind, resource, opts)
  opts = opts or {}
  local view_module = require("k8s.state.view")
  local view_type = view_module.get_describe_type_from_kind(kind)

  -- Create view state with lifecycle callbacks
  local view_state = view_module.create_describe_state(view_type, resource, {
    window = opts.window,
    on_mounted = function(view)
      M._on_mounted(view)
    end,
    on_unmounted = function(view)
      M._on_unmounted(view)
    end,
    render = function(view, win)
      M._render(view, win, kind)
    end,
  })

  -- Set describe output if provided
  if opts.describe_output then
    view_state.describe_output = opts.describe_output
  end

  return view_state
end

---Called when view is mounted (shown)
---@param _ ViewState (unused, but required for lifecycle interface)
function M._on_mounted(_)
  -- Describe view doesn't need watcher
  -- Just trigger render
  local state = require("k8s.state")
  state.notify()
end

---Called when view is unmounted (hidden)
---@param _ ViewState (unused, but required for lifecycle interface)
function M._on_unmounted(_)
  -- No cleanup needed for describe view
end

---Render the describe view
---@param view ViewState
---@param win table Window reference
---@param kind K8sResourceKind
function M._render(view, win, kind)
  local window = require("k8s.ui.nui.window")
  local state = require("k8s.state")
  local secret_mask = require("k8s.ui.components.secret_mask")

  if not win or not window.is_mounted(win) then
    return
  end

  local resource = view.resource or {}

  -- Update header
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = resource.namespace or state.get_namespace(),
      view = kind .. ": " .. (resource.name or ""),
    })
    window.set_lines(header_bufnr, { header_content })
    window.add_highlight(header_bufnr, "K8sHeader", 0, 0, #header_content)
  end

  -- Render describe output
  local content_bufnr = window.get_content_bufnr(win)
  if content_bufnr then
    local output = view.describe_output or ""
    local lines = vim.split(output, "\n")

    -- For Secret resources, inject actual values when not masked
    if kind == "Secret" and not view.mask_secrets and view.secret_data then
      lines = secret_mask.inject_secret_values(lines, view.secret_data)
    end

    window.set_lines(content_bufnr, lines)

    -- Apply YAML syntax highlighting
    vim.bo[content_bufnr].filetype = "yaml"
  end

  -- Update footer
  local keymaps = require("k8s.views.keymaps")
  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local footer_keymaps = keymaps.get_footer_keymaps(view.type)
    local footer_content = buffer.create_footer_content(footer_keymaps)
    window.set_lines(footer_bufnr, { footer_content })
    window.add_highlight(footer_bufnr, "K8sFooter", 0, 0, #footer_content)
  end
end

return M
