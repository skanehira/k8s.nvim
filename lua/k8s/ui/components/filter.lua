--- filter.lua - フィルター入力コンポーネント（vim.fn.inputコマンドライン）

local M = {}

---Create filter prompt string
---@return string prompt
function M.create_prompt()
  return "/"
end

---Parse user input
---@param input string|nil Raw input from vim.fn.input
---@return string parsed Parsed filter text
function M.parse_input(input)
  if input == nil or input == "" then
    return ""
  end

  -- Trim whitespace
  return input:match("^%s*(.-)%s*$")
end

---Check if filter should be cleared
---@param filter_text string Filter text
---@return boolean clear Should clear filter
function M.should_clear_filter(filter_text)
  return filter_text == ""
end

---Format filter text for header display
---@param filter_text string|nil Filter text
---@return string display Formatted display string
function M.format_display(filter_text)
  if filter_text == nil or filter_text == "" then
    return ""
  end
  return "Filter: " .. filter_text
end

return M
