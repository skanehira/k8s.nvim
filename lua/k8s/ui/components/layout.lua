--- layout.lua - 3ウィンドウレイアウト（ヘッダー/コンテンツ/フッター）

local M = {}

---Calculate dimensions for 3-window layout
---@param width number Screen width
---@param height number Screen height
---@return table dimensions Layout dimensions
function M.calculate_dimensions(width, height)
  local header_height = 1
  local footer_height = 1
  local content_height = height - header_height - footer_height

  return {
    width = width,
    total_height = height,
    header = {
      height = header_height,
      row = 1,
    },
    content = {
      height = content_height,
      row = header_height + 1,
    },
    footer = {
      height = footer_height,
      row = height,
    },
  }
end

---Create popup options for a specific section
---@param section "header"|"content"|"footer" Section name
---@param dims table Dimensions from calculate_dimensions
---@return table opts NuiPopup options
function M.create_popup_options(section, dims)
  local section_dims = dims[section]

  return {
    border = "none",
    size = {
      width = dims.width,
      height = section_dims.height,
    },
    position = {
      row = section_dims.row,
      col = 0,
    },
  }
end

return M
