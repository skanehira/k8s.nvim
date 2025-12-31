--- secret_mask.lua - Secretマスク表示コンポーネント

local M = {}

---Inject actual secret values into describe output lines
---@param lines string[] Lines from describe output
---@param secret_data table<string, string> Decoded secret data (key -> value)
---@return string[] Lines with injected values
function M.inject_secret_values(lines, secret_data)
  if not secret_data or vim.tbl_isempty(secret_data) then
    return lines
  end

  local result = {}
  local in_data_section = false

  for _, line in ipairs(lines) do
    -- Check for Data section header
    if line:match("^Data$") or line:match("^Data:$") then
      in_data_section = true
      table.insert(result, line)
    -- Check for next section (ends Data section) - starts with letter without indent
    elseif in_data_section and line:match("^[A-Z]") and not line:match("^%s") and not line:match("^=") then
      in_data_section = false
      table.insert(result, line)
    -- Skip separator lines like "===="
    elseif in_data_section and line:match("^=+$") then
      table.insert(result, line)
    -- Replace "key:  N bytes" with actual value
    elseif in_data_section and line:match("^[%w%-_%.]+:%s+%d+%s+bytes") then
      local key = line:match("^([%w%-_%.]+):")
      -- Capture the prefix including key and all spaces (preserve alignment)
      local prefix = line:match("^([%w%-_%.]+:%s+)")
      if key and secret_data[key] and prefix then
        -- Remove trailing newline only
        local value = secret_data[key]:gsub("\n$", "")
        -- For multiline values, add each line with proper indentation
        local value_lines = vim.split(value, "\n")
        if #value_lines == 1 then
          table.insert(result, prefix .. value_lines[1])
        else
          -- First line with key (preserve prefix spacing)
          table.insert(result, prefix .. "|")
          -- Subsequent lines indented to match
          local indent = string.rep(" ", #prefix)
          for _, vline in ipairs(value_lines) do
            table.insert(result, indent .. vline)
          end
        end
      else
        table.insert(result, line)
      end
    else
      table.insert(result, line)
    end
  end

  return result
end

return M
