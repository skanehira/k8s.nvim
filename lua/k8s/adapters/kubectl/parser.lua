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

local extractors = require("k8s.resources.extractors")
local registry = require("k8s.resources.registry")

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

-- Export utility functions for reuse (delegate to extractors)
M.parse_timestamp = extractors.parse_timestamp
M.format_duration = extractors.format_duration
M.calculate_age = extractors.calculate_age

---Parse kubectl get -o json output
---@param json string
---@return K8sResult
function M.parse_resources(json)
  local success, data = decode_json(json)
  if not success then
    return err("Failed to parse JSON: " .. tostring(data))
  end

  local items = data.items or {}

  -- Extract kind from list kind (e.g., "PodList" -> "Pod")
  -- If kind is just "List", get kind from first item
  local kind = extract_kind(data.kind or "")
  if kind == "" and #items > 0 and items[1].kind then
    kind = items[1].kind
  end

  local resources = {}

  for _, item in ipairs(items) do
    local metadata = item.metadata or {}
    -- Use item's kind if available, otherwise use list kind
    local item_kind = item.kind or kind
    table.insert(resources, {
      kind = item_kind,
      name = metadata.name or "",
      namespace = metadata.namespace or "",
      status = registry.extract_status(item, item_kind),
      age = extractors.calculate_age(metadata.creationTimestamp or ""),
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

---Parse a single resource from watch event
---@param item table Raw k8s resource object
---@return ParsedResource
function M.parse_single_resource(item)
  local metadata = item.metadata or {}
  local kind = item.kind or ""

  return {
    kind = kind,
    name = metadata.name or "",
    namespace = metadata.namespace or "",
    status = registry.extract_status(item, kind),
    age = extractors.calculate_age(metadata.creationTimestamp or ""),
    raw = item,
  }
end

return M
