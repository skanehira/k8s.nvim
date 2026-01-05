--- header.lua - ヘッダーのフォーマット

local M = {}

---Format header text
---@param opts table Header options
---@return string text Formatted header text
function M.format(opts)
  local parts = {}

  -- Context
  table.insert(parts, "[Context: " .. opts.context .. "]")

  -- Namespace
  local ns = opts.namespace == "All Namespaces" and "All" or opts.namespace
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

return M
