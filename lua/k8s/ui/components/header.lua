--- header.lua - ヘッダー・フッターのフォーマット

local M = {}

---Format header text
---@param opts table Header options
---@return string text Formatted header text
function M.format(opts)
  local parts = {}

  -- Context
  table.insert(parts, "[Context: " .. opts.context .. "]")

  -- Namespace
  local ns = opts.namespace or "All"
  table.insert(parts, "[Namespace: " .. ns .. "]")

  -- View
  table.insert(parts, "[" .. opts.view .. "]")

  -- Filter (if present)
  if opts.filter and opts.filter ~= "" then
    table.insert(parts, "Filter: " .. opts.filter)
  end

  -- Loading indicator
  if opts.loading then
    table.insert(parts, "Loading...")
  end

  return table.concat(parts, " ")
end

---Format footer text with keymaps
---@param keymaps string[] Keymap hints
---@return string text Formatted footer text
function M.format_footer(keymaps)
  return table.concat(keymaps, "  ")
end

return M
