--- registry.lua - リソース定義レジストリ
--- 全リソースの定義を集約した単一の source of truth

local extractors = require("k8s.resources.extractors")

local M = {}

---@alias K8sResourceKind
---| "Pod"
---| "Deployment"
---| "ReplicaSet"
---| "StatefulSet"
---| "DaemonSet"
---| "Job"
---| "CronJob"
---| "Service"
---| "ConfigMap"
---| "Secret"
---| "Node"
---| "Namespace"
---| "Ingress"
---| "Event"
---| "Application"
---| "PortForward"

---@class Column
---@field key string Data key for row extraction
---@field header string Display header text

---@class ResourceDefinition
---@field kind string
---@field plural string
---@field display_name string
---@field columns Column[]
---@field status_column_key string
---@field extract_status? fun(item: table): string
---@field extract_row fun(resource: table): table

---@type table<string, ResourceDefinition>
M.resources = {
  Pod = {
    kind = "Pod",
    plural = "pods",
    display_name = "Pods",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "status", header = "STATUS" },
      { key = "ready", header = "READY" },
      { key = "restarts", header = "RESTARTS" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "status",
    extract_status = function(item)
      return extractors.get_pod_status(item)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        ready = extractors.extract_pod_ready(raw),
        restarts = extractors.extract_pod_restarts(raw),
      }
    end,
  },

  Deployment = {
    kind = "Deployment",
    plural = "deployments",
    display_name = "Deployments",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "ready", header = "READY" },
      { key = "up_to_date", header = "UP-TO-DATE" },
      { key = "available", header = "AVAILABLE" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "ready",
    extract_status = function(item)
      local ready = item.status and item.status.readyReplicas or 0
      local desired = item.spec and item.spec.replicas or 0
      return string.format("%d/%d", ready, desired)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      local spec = raw.spec or {}
      local ready = status.readyReplicas or 0
      local desired = spec.replicas or 0
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        ready = string.format("%d/%d", ready, desired),
        up_to_date = status.updatedReplicas or 0,
        available = status.availableReplicas or 0,
      }
    end,
  },

  ReplicaSet = {
    kind = "ReplicaSet",
    plural = "replicasets",
    display_name = "ReplicaSets",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "desired", header = "DESIRED" },
      { key = "current", header = "CURRENT" },
      { key = "ready", header = "READY" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "ready",
    extract_status = function(item)
      local ready = item.status and item.status.readyReplicas or 0
      local desired = item.spec and item.spec.replicas or 0
      return string.format("%d/%d", ready, desired)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      local spec = raw.spec or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        desired = spec.replicas or 0,
        current = status.replicas or 0,
        ready = status.readyReplicas or 0,
      }
    end,
  },

  StatefulSet = {
    kind = "StatefulSet",
    plural = "statefulsets",
    display_name = "StatefulSets",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "ready", header = "READY" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "ready",
    extract_status = function(item)
      local ready = item.status and item.status.readyReplicas or 0
      local desired = item.spec and item.spec.replicas or 0
      return string.format("%d/%d", ready, desired)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      local spec = raw.spec or {}
      local ready = status.readyReplicas or 0
      local desired = spec.replicas or 0
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        ready = string.format("%d/%d", ready, desired),
      }
    end,
  },

  DaemonSet = {
    kind = "DaemonSet",
    plural = "daemonsets",
    display_name = "DaemonSets",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "ready", header = "READY" },
      { key = "available", header = "AVAILABLE" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "ready",
    extract_status = function(item)
      local ready = item.status and item.status.numberReady or 0
      local desired = item.status and item.status.desiredNumberScheduled or 0
      return string.format("%d/%d", ready, desired)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      local ready = status.numberReady or 0
      local desired = status.desiredNumberScheduled or 0
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        ready = string.format("%d/%d", ready, desired),
        available = status.numberAvailable or 0,
      }
    end,
  },

  Job = {
    kind = "Job",
    plural = "jobs",
    display_name = "Jobs",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "completions", header = "COMPLETIONS" },
      { key = "duration", header = "DURATION" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "completions",
    extract_status = function(item)
      local succeeded = item.status and item.status.succeeded or 0
      local completions = item.spec and item.spec.completions or 1
      return string.format("%d/%d", succeeded, completions)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      local spec = raw.spec or {}
      local succeeded = status.succeeded or 0
      local completions = spec.completions or 1
      local duration
      if status.startTime and status.completionTime then
        duration = extractors.calculate_job_duration(status.startTime, status.completionTime)
      elseif status.startTime then
        duration = "Running"
      else
        duration = "-"
      end
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        completions = string.format("%d/%d", succeeded, completions),
        duration = duration,
      }
    end,
  },

  CronJob = {
    kind = "CronJob",
    plural = "cronjobs",
    display_name = "CronJobs",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "schedule", header = "SCHEDULE" },
      { key = "suspend", header = "SUSPEND" },
      { key = "active", header = "ACTIVE" },
      { key = "last_schedule", header = "LAST SCHEDULE" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "schedule",
    extract_status = function(item)
      local active = item.status and item.status.active and #item.status.active or 0
      return string.format("%d active", active)
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      local spec = raw.spec or {}
      local last_schedule
      if status.lastScheduleTime then
        last_schedule = extractors.calculate_age(status.lastScheduleTime)
      else
        last_schedule = "<none>"
      end
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        schedule = spec.schedule or "<none>",
        suspend = spec.suspend and "True" or "False",
        active = status.active and #status.active or 0,
        last_schedule = last_schedule,
      }
    end,
  },

  Service = {
    kind = "Service",
    plural = "services",
    display_name = "Services",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "type", header = "TYPE" },
      { key = "cluster_ip", header = "CLUSTER-IP" },
      { key = "external_ip", header = "EXTERNAL-IP" },
      { key = "ports", header = "PORTS" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "type",
    extract_status = function(item)
      return item.spec and item.spec.type or "Unknown"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local spec = raw.spec or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        type = spec.type or "<unknown>",
        cluster_ip = spec.clusterIP or "<none>",
        external_ip = extractors.extract_service_external_ip(raw),
        ports = extractors.extract_service_ports(raw),
      }
    end,
  },

  ConfigMap = {
    kind = "ConfigMap",
    plural = "configmaps",
    display_name = "ConfigMaps",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "data", header = "DATA" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "status",
    extract_status = function(_)
      return "Active"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        data = extractors.extract_data_count(raw),
      }
    end,
  },

  Secret = {
    kind = "Secret",
    plural = "secrets",
    display_name = "Secrets",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "type", header = "TYPE" },
      { key = "data", header = "DATA" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "status",
    extract_status = function(_)
      return "Active"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        type = raw.type or "Opaque",
        data = extractors.extract_data_count(raw),
      }
    end,
  },

  Node = {
    kind = "Node",
    plural = "nodes",
    display_name = "Nodes",
    columns = {
      { key = "name", header = "NAME" },
      { key = "status", header = "STATUS" },
      { key = "roles", header = "ROLES" },
      { key = "age", header = "AGE" },
      { key = "version", header = "VERSION" },
    },
    status_column_key = "status",
    extract_status = function(item)
      if item.status and item.status.conditions then
        for _, cond in ipairs(item.status.conditions) do
          if cond.type == "Ready" then
            return cond.status == "True" and "Ready" or "NotReady"
          end
        end
      end
      return "Unknown"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        roles = extractors.extract_node_roles(raw),
        version = extractors.extract_node_version(raw),
      }
    end,
  },

  Namespace = {
    kind = "Namespace",
    plural = "namespaces",
    display_name = "Namespaces",
    columns = {
      { key = "name", header = "NAME" },
      { key = "status", header = "STATUS" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "status",
    extract_status = function(item)
      return item.status and item.status.phase or "Unknown"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = status.phase or resource.status,
        age = resource.age,
      }
    end,
  },

  Ingress = {
    kind = "Ingress",
    plural = "ingresses",
    display_name = "Ingresses",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "class", header = "CLASS" },
      { key = "hosts", header = "HOSTS" },
      { key = "address", header = "ADDRESS" },
      { key = "ports", header = "PORTS" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "class",
    extract_status = function(_)
      return "Active"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local spec = raw.spec or {}
      local status = raw.status or {}
      -- Hosts
      local hosts = {}
      if spec.rules then
        for _, rule in ipairs(spec.rules) do
          if rule.host then
            table.insert(hosts, rule.host)
          end
        end
      end
      -- Address
      local lb = status.loadBalancer or {}
      local ingress_list = lb.ingress or {}
      local address
      if #ingress_list > 0 then
        local addr = ingress_list[1].ip or ingress_list[1].hostname or ""
        address = addr ~= "" and addr or "<none>"
      else
        address = "<none>"
      end
      -- Ports
      local has_tls = spec.tls and #spec.tls > 0
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        class = spec.ingressClassName or "<none>",
        hosts = #hosts > 0 and table.concat(hosts, ",") or "*",
        address = address,
        ports = has_tls and "80, 443" or "80",
      }
    end,
  },

  Event = {
    kind = "Event",
    plural = "events",
    display_name = "Events",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "type", header = "TYPE" },
      { key = "reason", header = "REASON" },
      { key = "object", header = "OBJECT" },
      { key = "message", header = "MESSAGE" },
      { key = "count", header = "COUNT" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "type",
    extract_status = function(item)
      return item.type or "Normal"
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local involved = raw.involvedObject or {}
      local obj_kind = involved.kind or ""
      local obj_name = involved.name or ""
      local object = obj_kind ~= "" and obj_name ~= "" and string.format("%s/%s", obj_kind, obj_name) or "<none>"
      local msg = raw.message or ""
      if #msg > 50 then
        msg = msg:sub(1, 47) .. "..."
      end
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        type = raw.type or "Normal",
        reason = raw.reason or "",
        object = object,
        message = msg,
        count = raw.count or 1,
      }
    end,
  },

  Application = {
    kind = "Application",
    plural = "applications",
    display_name = "Applications",
    columns = {
      { key = "name", header = "NAME" },
      { key = "namespace", header = "NAMESPACE" },
      { key = "sync_status", header = "SYNC" },
      { key = "health_status", header = "HEALTH" },
      { key = "age", header = "AGE" },
    },
    status_column_key = "sync_status",
    extract_status = function(item)
      local sync = item.status and item.status.sync and item.status.sync.status or "Unknown"
      return sync
    end,
    extract_row = function(resource)
      local raw = resource.raw or {}
      local status = raw.status or {}
      return {
        name = resource.name,
        namespace = resource.namespace,
        status = resource.status,
        age = resource.age,
        sync_status = status.sync and status.sync.status or "Unknown",
        health_status = status.health and status.health.status or "Unknown",
      }
    end,
  },

  PortForward = {
    kind = "PortForward",
    plural = "portforwards",
    display_name = "Port Forwards",
    columns = {
      { key = "local_port", header = "LOCAL" },
      { key = "remote_port", header = "REMOTE" },
      { key = "resource", header = "RESOURCE" },
      { key = "status", header = "STATUS" },
    },
    status_column_key = "status",
    -- PortForward has no extract_status (not a K8s resource)
    extract_row = function(resource)
      return {
        local_port = resource.local_port,
        remote_port = resource.remote_port,
        resource = resource.resource,
        status = "Running",
      }
    end,
  },
}

-- =============================================================================
-- Registry API
-- =============================================================================

---Get resource definition by kind
---@param kind string
---@return ResourceDefinition|nil
function M.get(kind)
  return M.resources[kind]
end

---Get all resource kinds
---@return string[]
function M.all_kinds()
  local kinds = {}
  for kind in pairs(M.resources) do
    table.insert(kinds, kind)
  end
  table.sort(kinds)
  return kinds
end

---Get menu items for resource selection
---@return { text: string, value: string }[]
function M.get_menu_items()
  local items = {}
  for kind, def in pairs(M.resources) do
    table.insert(items, { text = def.display_name, value = kind })
  end
  table.sort(items, function(a, b)
    return a.text < b.text
  end)
  return items
end

---Get subcommands for command completion
---@return string[]
function M.get_subcommands()
  local cmds = { "open", "close", "context", "namespace" }
  for _, def in pairs(M.resources) do
    table.insert(cmds, def.plural)
  end
  table.sort(cmds)
  return cmds
end

---Get kind from plural name
---@param plural string e.g., "pods", "deployments"
---@return string|nil kind e.g., "Pod", "Deployment"
function M.get_kind_from_plural(plural)
  for kind, def in pairs(M.resources) do
    if def.plural == plural then
      return kind
    end
  end
  return nil
end

---Get plural name from kind
---@param kind string e.g., "Pod", "Deployment"
---@return string plural e.g., "pods", "deployments"
function M.get_plural_from_kind(kind)
  local def = M.resources[kind]
  if def then
    return def.plural
  end
  return string.lower(kind) .. "s"
end

---Get columns for a resource kind
---@param kind string
---@return Column[]
function M.get_columns(kind)
  local def = M.resources[kind]
  if def then
    return def.columns
  end
  return {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "status", header = "STATUS" },
    { key = "age", header = "AGE" },
  }
end

---Get status column key for a resource kind
---@param kind string
---@return string
function M.get_status_column_key(kind)
  local def = M.resources[kind]
  if def then
    return def.status_column_key
  end
  return "status"
end

---Extract status from raw item
---@param item table Raw K8s resource
---@param kind string
---@return string
function M.extract_status(item, kind)
  local def = M.resources[kind]
  if def and def.extract_status then
    return def.extract_status(item)
  end
  return "Unknown"
end

---Extract row data from resource
---@param resource table Parsed resource
---@return table
function M.extract_row(resource)
  local def = M.resources[resource.kind]
  if def and def.extract_row then
    return def.extract_row(resource)
  end
  return {
    name = resource.name,
    namespace = resource.namespace,
    status = resource.status,
    age = resource.age,
  }
end

return M
