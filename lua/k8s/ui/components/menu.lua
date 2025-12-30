--- menu.lua - メニュー表示（telescope優先、なければNuiMenu）

local M = {}

---Check if telescope is available
---@return boolean
function M.has_telescope()
  local ok, _ = pcall(require, "telescope")
  return ok
end

---@class MenuItem
---@field text string
---@field value any

---Create menu items from a list
---@param list (string|{text: string, value: any})[] List of items
---@return MenuItem[] items Menu items with text and value
function M.create_items(list)
  local items = {}

  for _, item in ipairs(list) do
    if type(item) == "string" then
      table.insert(items, { text = item, value = item })
    else
      table.insert(items, { text = item.text, value = item.value })
    end
  end

  return items
end

return M
