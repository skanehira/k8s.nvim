--- buffer.lua - バッファ描画ヘルパー

local M = {}

---Create header content string
---@param opts { context: string, namespace: string, view: string, filter?: string, loading?: boolean }
---@return string content Header content
function M.create_header_content(opts)
  local parts = {}

  table.insert(parts, string.format("Context: %s", opts.context))
  local ns = opts.namespace == "All Namespaces" and "All" or opts.namespace
  table.insert(parts, string.format("Namespace: %s", ns))
  table.insert(parts, string.format("View: %s", opts.view))

  if opts.filter and opts.filter ~= "" then
    table.insert(parts, string.format("Filter: %s", opts.filter))
  end

  if opts.loading then
    table.insert(parts, "[Loading...]")
  end

  return table.concat(parts, " | ")
end

---Create footer content string
---@param keymaps { key: string, action: string }[]
---@return string content Footer content
function M.create_footer_content(keymaps)
  if #keymaps == 0 then
    return ""
  end

  local parts = {}
  for _, km in ipairs(keymaps) do
    table.insert(parts, string.format("[%s] %s", km.key, km.action))
  end

  return table.concat(parts, "  ")
end

---Create table line from columns and row
---@param columns { key: string, header: string }[]
---@param widths number[]
---@param row table
---@return string line
function M.create_table_line(columns, widths, row)
  local parts = {}

  for i, col in ipairs(columns) do
    local value = row[col.key] or ""
    local padded = string.format("%-" .. widths[i] .. "s", tostring(value))
    table.insert(parts, padded)
  end

  return table.concat(parts, " ")
end

---Create header line from columns
---@param columns { key: string, header: string }[]
---@param widths number[]
---@return string line
function M.create_header_line(columns, widths)
  local parts = {}

  for i, col in ipairs(columns) do
    local padded = string.format("%-" .. widths[i] .. "s", col.header)
    table.insert(parts, padded)
  end

  return table.concat(parts, " ")
end

---Get highlight range for a column
---@param widths number[]
---@param col_index number
---@return { start_col: number, end_col: number }
function M.get_highlight_range(widths, col_index)
  local start_col = 0

  -- Sum widths of previous columns + spaces
  for i = 1, col_index - 1 do
    start_col = start_col + widths[i] + 1 -- +1 for space separator
  end

  local end_col = start_col + widths[col_index]

  return { start_col = start_col, end_col = end_col }
end

---Find column index by key
---@param columns { key: string, header: string }[]
---@param key string
---@return number|nil index
function M.find_status_column_index(columns, key)
  for i, col in ipairs(columns) do
    if col.key == key then
      return i
    end
  end
  return nil
end

---Calculate column widths
---@param columns { key: string, header: string }[]
---@param rows table[]
---@return number[] widths
local function calculate_widths(columns, rows)
  local widths = {}

  for i, col in ipairs(columns) do
    widths[i] = #col.header

    for _, row in ipairs(rows) do
      local value = row[col.key]
      if value then
        local len = #tostring(value)
        if len > widths[i] then
          widths[i] = len
        end
      end
    end
  end

  return widths
end

---Prepare table content with header and rows (separated)
---@param columns { key: string, header: string }[]
---@param rows table[]
---@return { header_line: string, data_lines: string[], widths: number[] }
function M.prepare_table_content(columns, rows)
  local widths = calculate_widths(columns, rows)

  -- Header line
  local header_line = M.create_header_line(columns, widths)

  -- Data rows
  local data_lines = {}
  for _, row in ipairs(rows) do
    table.insert(data_lines, M.create_table_line(columns, widths, row))
  end

  return { header_line = header_line, data_lines = data_lines, widths = widths }
end

---Create initial buffer state
---@return table state
function M.create_buffer_state()
  return {
    bufnr = nil,
    lines = {},
  }
end

return M
