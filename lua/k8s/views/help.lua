--- help.lua - ヘルプ表示ビュー
--- Lifecycle: on_mounted (なし), on_unmounted (なし), render (ヘルプ表示)

local M = {}

local keymaps = require("k8s.views.keymaps")
local buffer = require("k8s.ui.nui.buffer")

-- =============================================================================
-- View Factory
-- =============================================================================

---Create a help view with lifecycle callbacks
---@param parent_type string Parent view type to show help for
---@param opts? { window?: table }
---@return ViewState
function M.create_view(parent_type, opts)
  opts = opts or {}
  local view_module = require("k8s.state.view")

  -- Pre-generate help content
  local help_lines = M.create_content(parent_type)

  -- Create view state with lifecycle callbacks
  local view_state = view_module.create_help_state({
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

  -- Store help content and parent type
  view_state.help_content = help_lines
  view_state.parent_type = parent_type

  return view_state
end

---Called when view is mounted (shown)
---@param _ ViewState (unused, but required for lifecycle interface)
function M._on_mounted(_)
  -- Help view doesn't need watcher
  local state = require("k8s.state")
  state.notify()
end

---Called when view is unmounted (hidden)
---@param _ ViewState (unused, but required for lifecycle interface)
function M._on_unmounted(_)
  -- No cleanup needed for help view
end

---Render the help view
---@param view ViewState
---@param win table Window reference
function M._render(view, win)
  local window = require("k8s.ui.nui.window")
  local state = require("k8s.state")

  if not win or not window.is_mounted(win) then
    return
  end

  -- Update header
  local header_bufnr = window.get_header_bufnr(win)
  if header_bufnr then
    local header_content = buffer.create_header_content({
      context = vim.fn.system("kubectl config current-context"):gsub("\n", ""),
      namespace = state.get_namespace(),
      view = "Help",
    })
    window.set_lines(header_bufnr, { header_content })
    window.add_highlight(header_bufnr, "K8sHeader", 0, 0, #header_content)
  end

  -- Render help content
  local content_bufnr = window.get_content_bufnr(win)
  if content_bufnr then
    local help_lines = view.help_content or {}
    window.set_lines(content_bufnr, help_lines)
  end

  -- Update footer
  local footer_bufnr = window.get_footer_bufnr(win)
  if footer_bufnr then
    local footer_keymaps = keymaps.get_footer_keymaps("help")
    local footer_content = buffer.create_footer_content(footer_keymaps)
    window.set_lines(footer_bufnr, { footer_content })
    window.add_highlight(footer_bufnr, "K8sFooter", 0, 0, #footer_content)
  end
end

-- =============================================================================
-- Content Generation
-- =============================================================================

---Format keymaps into display lines with aligned columns
---@param keymap_defs KeymapDef[] Array of keymap definitions
---@param items_per_line number Number of items per line
---@return string[] lines Formatted lines
function M.format_keymap_lines(keymap_defs, items_per_line)
  if #keymap_defs == 0 then
    return {}
  end

  -- Calculate max widths for key and action
  local max_key_width = 0
  local max_desc_width = 0
  for _, km in ipairs(keymap_defs) do
    max_key_width = math.max(max_key_width, #km.key)
    max_desc_width = math.max(max_desc_width, #km.desc)
  end

  -- Format each keymap with fixed width
  local format_str = "%-" .. max_key_width .. "s %-" .. max_desc_width .. "s"

  local lines = {}
  local current_line = {}

  for i, km in ipairs(keymap_defs) do
    local formatted = string.format(format_str, km.key, km.desc)
    table.insert(current_line, formatted)

    if #current_line >= items_per_line or i == #keymap_defs then
      table.insert(lines, table.concat(current_line, "  "))
      current_line = {}
    end
  end

  return lines
end

---Create help content for a view type
---@param view_type string View type to show help for
---@return string[] lines Help content lines
function M.create_content(view_type)
  local lines = {}
  table.insert(lines, "Keymaps:")
  table.insert(lines, "")

  local keymap_defs = keymaps.get_keymaps(view_type)

  -- Sort by key for consistent display
  local sorted = vim.deepcopy(keymap_defs)
  table.sort(sorted, function(a, b)
    return a.key < b.key
  end)

  -- Format keymaps (4 items per line)
  local keymap_lines = M.format_keymap_lines(sorted, 4)
  for _, line in ipairs(keymap_lines) do
    table.insert(lines, line)
  end

  return lines
end

return M
