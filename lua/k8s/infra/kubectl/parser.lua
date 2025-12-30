---@class K8sResult
---@field ok boolean
---@field data any
---@field error string|nil

---@class ParsedResource
---@field kind string
---@field name string
---@field namespace string
---@field status string
---@field age string
---@field raw table

local M = {}

---Create a success result
---@param data any
---@return K8sResult
local function ok(data)
  return { ok = true, data = data, error = nil }
end

---Create an error result
---@param message string
---@return K8sResult
local function err(message)
  return { ok = false, data = nil, error = message }
end

---Safely decode JSON
---@param json string
---@return boolean, table|string
local function decode_json(json)
  return pcall(vim.json.decode, json)
end

---Extract kind from list kind (e.g., "PodList" -> "Pod")
---@param list_kind string
---@return string
local function extract_kind(list_kind)
  return (list_kind:gsub("List$", ""))
end

---Calculate age from creation timestamp
---@param timestamp string ISO 8601 format (e.g., "2024-12-30T10:00:00Z")
---@return string
local function calculate_age(timestamp)
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = timestamp:match(pattern)
  if not year then
    return "unknown"
  end

  local created = os.time({
    year = assert(tonumber(year)),
    month = assert(tonumber(month)),
    day = assert(tonumber(day)),
    hour = assert(tonumber(hour)),
    min = assert(tonumber(min)),
    sec = assert(tonumber(sec)),
  })
  local now = os.time(os.date("!*t") --[[@as osdateparam]])
  local diff = now - created

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

---Get status from resource based on kind
---@param item table
---@param kind string
---@return string
local function get_status(item, kind)
  if kind == "Pod" then
    return item.status and item.status.phase or "Unknown"
  elseif kind == "Deployment" then
    local ready = item.status and item.status.readyReplicas or 0
    local desired = item.spec and item.spec.replicas or 0
    return string.format("%d/%d", ready, desired)
  elseif kind == "Service" then
    return item.spec and item.spec.type or "Unknown"
  elseif kind == "Node" then
    if item.status and item.status.conditions then
      for _, cond in ipairs(item.status.conditions) do
        if cond.type == "Ready" then
          return cond.status == "True" and "Ready" or "NotReady"
        end
      end
    end
    return "Unknown"
  else
    return "Active"
  end
end

---Parse kubectl get -o json output
---@param json string
---@return K8sResult
function M.parse_resources(json)
  local success, data = decode_json(json)
  if not success then
    return err("Failed to parse JSON: " .. tostring(data))
  end

  local kind = extract_kind(data.kind or "")
  local items = data.items or {}
  local resources = {}

  for _, item in ipairs(items) do
    local metadata = item.metadata or {}
    table.insert(resources, {
      kind = kind,
      name = metadata.name or "",
      namespace = metadata.namespace or "",
      status = get_status(item, kind),
      age = calculate_age(metadata.creationTimestamp or ""),
      raw = item,
    })
  end

  return ok(resources)
end

---Parse kubectl config get-contexts output
---@param output string
---@return K8sResult
function M.parse_contexts(output)
  local contexts = {}
  for line in output:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      table.insert(contexts, trimmed)
    end
  end
  return ok(contexts)
end

---Parse kubectl get namespaces -o json output
---@param json string
---@return K8sResult
function M.parse_namespaces(json)
  local success, data = decode_json(json)
  if not success then
    return err("Failed to parse JSON: " .. tostring(data))
  end

  local items = data.items or {}
  local namespaces = {}

  for _, item in ipairs(items) do
    local name = item.metadata and item.metadata.name
    if name then
      table.insert(namespaces, name)
    end
  end

  return ok(namespaces)
end

return M
