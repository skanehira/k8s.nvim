--- table.lua - テーブル描画（カラム幅計算、行フォーマット）

local M = {}

-- ステータスとハイライトグループのマッピング
local status_highlights = {
  -- 緑（正常）
  Running = "K8sStatusRunning",
  Completed = "K8sStatusRunning",
  Active = "K8sStatusRunning",
  Ready = "K8sStatusRunning",
  Synced = "K8sStatusRunning",
  Healthy = "K8sStatusRunning",
  Normal = "K8sStatusRunning",
  -- 黄（待機中）
  Pending = "K8sStatusPending",
  Waiting = "K8sStatusPending",
  ContainerCreating = "K8sStatusPending",
  OutOfSync = "K8sStatusPending",
  Progressing = "K8sStatusPending",
  Suspended = "K8sStatusPending",
  Warning = "K8sStatusPending",
  -- 赤（エラー）
  Error = "K8sStatusError",
  Failed = "K8sStatusError",
  CrashLoopBackOff = "K8sStatusError",
  CreateContainerConfigError = "K8sStatusError",
  Terminating = "K8sStatusError",
  Degraded = "K8sStatusError",
  Missing = "K8sStatusError",
}

---Calculate column widths based on header and data
---@param columns table[] Column definitions with key and header
---@param rows table[] Data rows
---@return number[] widths Column widths
function M.calculate_column_widths(columns, rows)
  local widths = {}

  for i, col in ipairs(columns) do
    -- Start with header width
    widths[i] = #col.header

    -- Check each row for longer values
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

---Format a data row with padding
---@param columns table[] Column definitions
---@param widths number[] Column widths
---@param row table Data row
---@return string formatted Formatted row string
function M.format_row(columns, widths, row)
  local parts = {}

  for i, col in ipairs(columns) do
    local value = row[col.key] or ""
    local padded = string.format("%-" .. widths[i] .. "s", tostring(value))
    table.insert(parts, padded)
  end

  return table.concat(parts, " ")
end

---Format header row with padding
---@param columns table[] Column definitions
---@param widths number[] Column widths
---@return string formatted Formatted header string
function M.format_header(columns, widths)
  local parts = {}

  for i, col in ipairs(columns) do
    local padded = string.format("%-" .. widths[i] .. "s", col.header)
    table.insert(parts, padded)
  end

  return table.concat(parts, " ")
end

---Get highlight group for status
---@param status string Status string
---@return string|nil highlight Highlight group name or nil
function M.get_status_highlight(status)
  return status_highlights[status]
end

return M
