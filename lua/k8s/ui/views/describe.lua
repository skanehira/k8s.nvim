--- describe.lua - describe View

local resource = require("k8s.core.resource")

local M = {}

-- Default keymap definitions for describe view
local default_keymaps = {
  ["<C-h>"] = "back",
  ["l"] = "logs",
  ["e"] = "exec",
  ["D"] = "delete",
  ["q"] = "quit",
}

---Get default keymap definitions
---@return table<string, string> keymaps Key to action mapping
function M.get_default_keymaps()
  return default_keymaps
end

---Get action name for a key
---@param key string Key press
---@return string|nil action Action name or nil
function M.get_action_for_key(key)
  return default_keymaps[key]
end

---@class DescribeHeaderInfo
---@field kind string Resource kind
---@field name string Resource name
---@field namespace string Namespace

---Format header information for describe view
---@param kind string Resource kind
---@param name string Resource name
---@param namespace string Namespace
---@return DescribeHeaderInfo
function M.format_header_info(kind, name, namespace)
  return {
    kind = kind,
    name = name,
    namespace = namespace,
  }
end

---Get filetype for describe buffer
---@return string filetype
function M.get_filetype()
  return "yaml"
end

---Check if an action can be performed on this resource
---@param kind string Resource kind
---@param action string Action name
---@return boolean
function M.can_perform_action(kind, action)
  -- delete is always available
  if action == "delete" then
    return true
  end

  -- Check resource capabilities for other actions
  local caps = resource.capabilities(kind)
  if caps[action] == nil then
    return false
  end
  return caps[action]
end

-- =============================================================================
-- View Rendering
-- =============================================================================

---@class DescribeViewRenderOptions
---@field lines string[] Lines to render
---@field kind string Resource kind
---@field name string Resource name
---@field namespace string Resource namespace
---@field mask_secrets? boolean Whether to mask secrets

---Render describe view (content only, hide table_header)
---@param win K8sWindow Window instance
---@param opts DescribeViewRenderOptions
function M.render(win, opts)
  local window = require("k8s.ui.nui.window")

  -- Hide table header for describe view
  window.hide_table_header(win)

  -- Render content
  local content_bufnr = window.get_content_bufnr(win)
  if not content_bufnr then
    return
  end

  local lines = opts.lines

  -- Apply secret mask if needed
  if opts.kind == "Secret" and opts.mask_secrets then
    local secret_mask = require("k8s.ui.components.secret_mask")
    lines = secret_mask.mask_describe_output(true, lines)
  end

  window.set_lines(content_bufnr, lines)

  -- Set filetype for syntax highlighting
  vim.api.nvim_buf_set_option(content_bufnr, "filetype", M.get_filetype())

  -- Set cursor to top
  window.set_cursor(win, 1, 0)
end

return M
