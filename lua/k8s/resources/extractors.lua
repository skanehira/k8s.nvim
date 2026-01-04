--- extractors.lua - リソース抽出ヘルパー関数
--- registry.lua から使用される

local M = {}

-- =============================================================================
-- Timestamp Utilities (from parser.lua)
-- =============================================================================

---Parse ISO 8601 timestamp to os.time
---@param timestamp string ISO 8601 format (e.g., "2024-12-30T10:00:00Z")
---@return number|nil
function M.parse_timestamp(timestamp)
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = timestamp:match(pattern)
  if not year then
    return nil
  end
  return os.time({
    year = assert(tonumber(year)),
    month = assert(tonumber(month)),
    day = assert(tonumber(day)),
    hour = assert(tonumber(hour)),
    min = assert(tonumber(min)),
    sec = assert(tonumber(sec)),
  })
end

---Format duration in seconds to human-readable string
---@param diff number Duration in seconds
---@return string
function M.format_duration(diff)
  if diff < 60 then
    return string.format("%ds", diff)
  elseif diff < 3600 then
    return string.format("%dm", math.floor(diff / 60))
  elseif diff < 86400 then
    return string.format("%dh", math.floor(diff / 3600))
  else
    return string.format("%dd", math.floor(diff / 86400))
  end
end

---Calculate age from creation timestamp
---@param timestamp string ISO 8601 format (e.g., "2024-12-30T10:00:00Z")
---@return string
function M.calculate_age(timestamp)
  local created = M.parse_timestamp(timestamp)
  if not created then
    return "unknown"
  end
  local now = os.time(os.date("!*t") --[[@as osdateparam]])
  local diff = now - created
  return M.format_duration(diff)
end

-- =============================================================================
-- Pod Status Extraction (from parser.lua)
-- =============================================================================

---Get Pod status with detailed container state
---@param item table Pod resource
---@return string
function M.get_pod_status(item)
  if not item.status then
    return "Unknown"
  end

  -- Check init container statuses first
  if item.status.initContainerStatuses then
    for i, cs in ipairs(item.status.initContainerStatuses) do
      if cs.state then
        if cs.state.waiting and cs.state.waiting.reason then
          return "Init:" .. i - 1 .. "/" .. #item.status.initContainerStatuses
        end
        if cs.state.terminated and cs.state.terminated.exitCode ~= 0 then
          return "Init:Error"
        end
        -- If still running, show init progress
        if cs.state.running then
          return "Init:" .. i - 1 .. "/" .. #item.status.initContainerStatuses
        end
      end
    end
  end

  -- Check container statuses for waiting/terminated states
  if item.status.containerStatuses then
    for _, cs in ipairs(item.status.containerStatuses) do
      if cs.state then
        -- Check waiting state (ContainerCreating, ImagePullBackOff, CrashLoopBackOff, etc.)
        if cs.state.waiting and cs.state.waiting.reason then
          return cs.state.waiting.reason
        end
        -- Check terminated state with error
        if cs.state.terminated and cs.state.terminated.reason then
          if cs.state.terminated.exitCode ~= 0 then
            return cs.state.terminated.reason
          end
        end
      end
    end
  end

  -- Fall back to phase
  return item.status.phase or "Unknown"
end

-- =============================================================================
-- Row Extraction Helpers (from columns.lua)
-- =============================================================================

---Extract Pod ready count
---@param raw table Raw resource data
---@return string ready Ready count (e.g., "2/3")
function M.extract_pod_ready(raw)
  local container_statuses = raw.status and raw.status.containerStatuses
  local spec_containers = raw.spec and raw.spec.containers

  if container_statuses then
    local ready_count = 0
    for _, cs in ipairs(container_statuses) do
      if cs.ready then
        ready_count = ready_count + 1
      end
    end
    return string.format("%d/%d", ready_count, #container_statuses)
  elseif spec_containers then
    return string.format("0/%d", #spec_containers)
  end

  return "0/0"
end

---Extract Pod restart count
---@param raw table Raw resource data
---@return number restarts Total restart count
function M.extract_pod_restarts(raw)
  local container_statuses = raw.status and raw.status.containerStatuses
  if not container_statuses then
    return 0
  end

  local total = 0
  for _, cs in ipairs(container_statuses) do
    total = total + (cs.restartCount or 0)
  end
  return total
end

---Extract Service ports
---@param raw table Raw resource data
---@return string ports Formatted ports string
function M.extract_service_ports(raw)
  local spec_ports = raw.spec and raw.spec.ports
  if not spec_ports or #spec_ports == 0 then
    return "<none>"
  end

  local port_strs = {}
  for _, p in ipairs(spec_ports) do
    table.insert(port_strs, string.format("%d/%s", p.port, p.protocol or "TCP"))
  end

  return table.concat(port_strs, ",")
end

---Extract Service external IP
---@param raw table Raw resource data
---@return string external_ip External IP or <none>
function M.extract_service_external_ip(raw)
  local ingress = raw.status and raw.status.loadBalancer and raw.status.loadBalancer.ingress
  if ingress and #ingress > 0 then
    return ingress[1].ip or ingress[1].hostname or "<none>"
  end
  return "<none>"
end

---Extract ConfigMap/Secret data count
---@param raw table Raw resource data
---@return number count Data entry count
function M.extract_data_count(raw)
  local count = 0
  if raw.data then
    for _ in pairs(raw.data) do
      count = count + 1
    end
  end
  if raw.binaryData then
    for _ in pairs(raw.binaryData) do
      count = count + 1
    end
  end
  return count
end

---Extract Node roles
---@param raw table Raw resource data
---@return string roles Comma-separated roles or <none>
function M.extract_node_roles(raw)
  local labels = raw.metadata and raw.metadata.labels
  if not labels then
    return "<none>"
  end

  local roles = {}
  for label in pairs(labels) do
    local role = label:match("^node%-role%.kubernetes%.io/(.+)$")
    if role then
      table.insert(roles, role)
    end
  end

  if #roles == 0 then
    return "<none>"
  end

  table.sort(roles)
  return table.concat(roles, ",")
end

---Extract Node version
---@param raw table Raw resource data
---@return string version Kubelet version
function M.extract_node_version(raw)
  local node_info = raw.status and raw.status.nodeInfo
  if node_info and node_info.kubeletVersion then
    return node_info.kubeletVersion
  end
  return "<unknown>"
end

---Calculate Job duration from start and end timestamps
---@param start_time string ISO 8601 format
---@param end_time string ISO 8601 format
---@return string duration Formatted duration string
function M.calculate_job_duration(start_time, end_time)
  local start_ts = M.parse_timestamp(start_time)
  local end_ts = M.parse_timestamp(end_time)
  if not start_ts or not end_ts then
    return "<unknown>"
  end
  local diff = end_ts - start_ts

  if diff < 60 then
    return string.format("%ds", diff)
  elseif diff < 3600 then
    return string.format("%dm%ds", math.floor(diff / 60), diff % 60)
  else
    return string.format("%dh%dm", math.floor(diff / 3600), math.floor((diff % 3600) / 60))
  end
end

return M
