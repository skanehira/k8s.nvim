--- columns.lua - リソースタイプごとのカラム定義

local parser = require("k8s.adapters.kubectl.parser")

local M = {}

---@class Column
---@field key string Data key for row extraction
---@field header string Display header text

---@type table<string, Column[]>
local column_definitions = {
  Pod = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "status", header = "STATUS" },
    { key = "ready", header = "READY" },
    { key = "restarts", header = "RESTARTS" },
    { key = "age", header = "AGE" },
  },
  Deployment = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "ready", header = "READY" },
    { key = "up_to_date", header = "UP-TO-DATE" },
    { key = "available", header = "AVAILABLE" },
    { key = "age", header = "AGE" },
  },
  Service = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "type", header = "TYPE" },
    { key = "cluster_ip", header = "CLUSTER-IP" },
    { key = "external_ip", header = "EXTERNAL-IP" },
    { key = "ports", header = "PORTS" },
    { key = "age", header = "AGE" },
  },
  ConfigMap = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "data", header = "DATA" },
    { key = "age", header = "AGE" },
  },
  Secret = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "type", header = "TYPE" },
    { key = "data", header = "DATA" },
    { key = "age", header = "AGE" },
  },
  Node = {
    { key = "name", header = "NAME" },
    { key = "status", header = "STATUS" },
    { key = "roles", header = "ROLES" },
    { key = "age", header = "AGE" },
    { key = "version", header = "VERSION" },
  },
  Namespace = {
    { key = "name", header = "NAME" },
    { key = "status", header = "STATUS" },
    { key = "age", header = "AGE" },
  },
  Application = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "sync_status", header = "SYNC" },
    { key = "health_status", header = "HEALTH" },
    { key = "age", header = "AGE" },
  },
  StatefulSet = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "ready", header = "READY" },
    { key = "age", header = "AGE" },
  },
  DaemonSet = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "ready", header = "READY" },
    { key = "available", header = "AVAILABLE" },
    { key = "age", header = "AGE" },
  },
  Job = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "completions", header = "COMPLETIONS" },
    { key = "duration", header = "DURATION" },
    { key = "age", header = "AGE" },
  },
  CronJob = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "schedule", header = "SCHEDULE" },
    { key = "suspend", header = "SUSPEND" },
    { key = "active", header = "ACTIVE" },
    { key = "last_schedule", header = "LAST SCHEDULE" },
    { key = "age", header = "AGE" },
  },
  Event = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "type", header = "TYPE" },
    { key = "reason", header = "REASON" },
    { key = "object", header = "OBJECT" },
    { key = "message", header = "MESSAGE" },
    { key = "count", header = "COUNT" },
    { key = "age", header = "AGE" },
  },
  Ingress = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "class", header = "CLASS" },
    { key = "hosts", header = "HOSTS" },
    { key = "address", header = "ADDRESS" },
    { key = "ports", header = "PORTS" },
    { key = "age", header = "AGE" },
  },
  PortForward = {
    { key = "local_port", header = "LOCAL" },
    { key = "remote_port", header = "REMOTE" },
    { key = "resource", header = "RESOURCE" },
    { key = "status", header = "STATUS" },
  },
}

local default_columns = {
  { key = "name", header = "NAME" },
  { key = "namespace", header = "NAMESPACE" },
  { key = "status", header = "STATUS" },
  { key = "age", header = "AGE" },
}

---Get columns for a resource kind
---@param kind K8sResourceKind Resource kind
---@return Column[]
function M.get_columns(kind)
  return column_definitions[kind] or default_columns
end

---Extract Pod ready count
---@param raw table Raw resource data
---@return string ready Ready count (e.g., "2/3")
local function extract_pod_ready(raw)
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
local function extract_pod_restarts(raw)
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
local function extract_service_ports(raw)
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
local function extract_service_external_ip(raw)
  local ingress = raw.status and raw.status.loadBalancer and raw.status.loadBalancer.ingress
  if ingress and #ingress > 0 then
    return ingress[1].ip or ingress[1].hostname or "<none>"
  end
  return "<none>"
end

---Extract ConfigMap/Secret data count
---@param raw table Raw resource data
---@return number count Data entry count
local function extract_data_count(raw)
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
local function extract_node_roles(raw)
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
local function extract_node_version(raw)
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
local function calculate_job_duration(start_time, end_time)
  local start_ts = parser.parse_timestamp(start_time)
  local end_ts = parser.parse_timestamp(end_time)
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

---Extract row data from resource
---@param resource table Resource with kind, name, namespace, status, age, raw
---@return table row Row data with keys matching column definitions
function M.extract_row(resource)
  local row = {
    name = resource.name,
    namespace = resource.namespace,
    status = resource.status,
    age = resource.age,
  }

  local kind = resource.kind
  local raw = resource.raw or {}

  if kind == "Pod" then
    row.ready = extract_pod_ready(raw)
    row.restarts = extract_pod_restarts(raw)
  elseif kind == "Deployment" then
    local status = raw.status or {}
    local spec = raw.spec or {}
    local ready = status.readyReplicas or 0
    local desired = spec.replicas or 0
    row.ready = string.format("%d/%d", ready, desired)
    row.up_to_date = status.updatedReplicas or 0
    row.available = status.availableReplicas or 0
  elseif kind == "Service" then
    local spec = raw.spec or {}
    row.type = spec.type or "<unknown>"
    row.cluster_ip = spec.clusterIP or "<none>"
    row.external_ip = extract_service_external_ip(raw)
    row.ports = extract_service_ports(raw)
  elseif kind == "ConfigMap" then
    row.data = extract_data_count(raw)
  elseif kind == "Secret" then
    row.type = raw.type or "Opaque"
    row.data = extract_data_count(raw)
  elseif kind == "Node" then
    row.roles = extract_node_roles(raw)
    row.version = extract_node_version(raw)
  elseif kind == "Namespace" then
    local status = raw.status or {}
    row.status = status.phase or resource.status
  elseif kind == "Application" then
    local status = raw.status or {}
    row.sync_status = status.sync and status.sync.status or "Unknown"
    row.health_status = status.health and status.health.status or "Unknown"
  elseif kind == "StatefulSet" then
    local status = raw.status or {}
    local spec = raw.spec or {}
    local ready = status.readyReplicas or 0
    local desired = spec.replicas or 0
    row.ready = string.format("%d/%d", ready, desired)
  elseif kind == "DaemonSet" then
    local status = raw.status or {}
    local ready = status.numberReady or 0
    local desired = status.desiredNumberScheduled or 0
    row.ready = string.format("%d/%d", ready, desired)
    row.available = status.numberAvailable or 0
  elseif kind == "Job" then
    local status = raw.status or {}
    local spec = raw.spec or {}
    local succeeded = status.succeeded or 0
    local completions = spec.completions or 1
    row.completions = string.format("%d/%d", succeeded, completions)
    -- Calculate duration
    if status.startTime and status.completionTime then
      local start_time = status.startTime
      local end_time = status.completionTime
      row.duration = calculate_job_duration(start_time, end_time)
    elseif status.startTime then
      row.duration = "Running"
    else
      row.duration = "-"
    end
  elseif kind == "CronJob" then
    local status = raw.status or {}
    local spec = raw.spec or {}
    row.schedule = spec.schedule or "<none>"
    row.suspend = spec.suspend and "True" or "False"
    row.active = status.active and #status.active or 0
    -- Last schedule time
    if status.lastScheduleTime then
      row.last_schedule = parser.calculate_age(status.lastScheduleTime)
    else
      row.last_schedule = "<none>"
    end
  elseif kind == "Ingress" then
    local spec = raw.spec or {}
    local status = raw.status or {}
    -- IngressClassName
    row.class = spec.ingressClassName or "<none>"
    -- Hosts
    local hosts = {}
    if spec.rules then
      for _, rule in ipairs(spec.rules) do
        if rule.host then
          table.insert(hosts, rule.host)
        end
      end
    end
    row.hosts = #hosts > 0 and table.concat(hosts, ",") or "*"
    -- Address (from LoadBalancer status)
    local lb = status.loadBalancer or {}
    local ingress_list = lb.ingress or {}
    if #ingress_list > 0 then
      local addr = ingress_list[1].ip or ingress_list[1].hostname or ""
      row.address = addr ~= "" and addr or "<none>"
    else
      row.address = "<none>"
    end
    -- Ports (check if TLS is configured)
    local has_tls = spec.tls and #spec.tls > 0
    row.ports = has_tls and "80, 443" or "80"
  elseif kind == "Event" then
    row.type = raw.type or "Normal"
    row.reason = raw.reason or ""
    -- Build object reference (kind/name)
    local involved = raw.involvedObject or {}
    local obj_kind = involved.kind or ""
    local obj_name = involved.name or ""
    row.object = obj_kind ~= "" and obj_name ~= "" and string.format("%s/%s", obj_kind, obj_name) or "<none>"
    -- Truncate message if too long
    local msg = raw.message or ""
    if #msg > 50 then
      row.message = msg:sub(1, 47) .. "..."
    else
      row.message = msg
    end
    row.count = raw.count or 1
  end

  return row
end

---@type table<string, string>
local status_column_keys = {
  Pod = "status",
  Deployment = "ready",
  Service = "type",
  ConfigMap = "status",
  Secret = "status",
  Node = "status",
  Namespace = "status",
  Application = "sync_status",
  StatefulSet = "ready",
  DaemonSet = "ready",
  Job = "completions",
  CronJob = "schedule",
  Event = "type",
  Ingress = "class",
  PortForward = "status",
}

---Get the key of the column used for status highlighting
---@param kind K8sResourceKind Resource kind
---@return string key Column key for status
function M.get_status_column_key(kind)
  return status_column_keys[kind] or "status"
end

return M
