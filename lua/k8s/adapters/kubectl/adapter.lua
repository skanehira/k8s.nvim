---@class KubectlAdapter
---@field get_resources fun(kind: string, namespace: string, callback: fun(result: K8sResult))

local parser = require("k8s.adapters.kubectl.parser")

local M = {}

-- Default executor using vim.system
local executor = vim.system

-- Default term opener: opens a new tab and runs terminal command
---@param cmd string
---@param opts? { on_exit?: function, tab_name?: string }
local function default_term_opener(cmd, opts)
  opts = opts or {}

  -- Open a new tab for the terminal
  vim.cmd("tabnew")

  -- Run terminal command in the new buffer
  local job_opts = { term = true }
  if opts.on_exit then
    job_opts.on_exit = opts.on_exit
  end
  local job_id = vim.fn.jobstart(cmd, job_opts)

  -- Set buffer name if provided (use file command for terminal buffers)
  if opts.tab_name then
    -- Escape special characters for file command
    local escaped_name = opts.tab_name:gsub(" ", "\\ ")
    vim.cmd("file " .. escaped_name)
  end

  return job_id
end
local term_opener = default_term_opener

---Set custom executor for testing
---@param exec function
function M._set_executor(exec)
  executor = exec
end

---Reset executor to default
function M._reset_executor()
  executor = vim.system
end

---Set custom term opener for testing
---@param opener function
function M._set_term_opener(opener)
  term_opener = opener
end

---Reset term opener to default
function M._reset_term_opener()
  term_opener = default_term_opener
end

-- Default job starter for background processes
local job_starter = vim.fn.jobstart

---Set custom job starter for testing
---@param starter function
function M._set_job_starter(starter)
  job_starter = starter
end

---Reset job starter to default
function M._reset_job_starter()
  job_starter = vim.fn.jobstart
end

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

---Build kubectl command arguments with namespace
---@param args string[]
---@param namespace string "All Namespaces" for all namespaces, otherwise specific namespace
---@return string[]
local function build_cmd_with_ns(args, namespace)
  local cmd = { "kubectl" }
  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end

  if namespace == "All Namespaces" then
    table.insert(cmd, "--all-namespaces")
  else
    table.insert(cmd, "-n")
    table.insert(cmd, namespace)
  end

  return cmd
end

---Run async kubectl command with common error handling
---@param cmd string[]
---@param on_success fun(stdout: string): K8sResult
---@param callback fun(result: K8sResult)
local function run_async(cmd, on_success, callback)
  executor(cmd, { text = true }, function(result)
    if result.code ~= 0 then
      callback(err("kubectl error: " .. (result.stderr or "unknown error")))
      return
    end
    callback(on_success(result.stdout))
  end)
end

---Get resources from kubectl
---@param kind string kubectl resource name (e.g., "pods", "deployments")
---@param namespace string
---@param callback fun(result: K8sResult)
function M.get_resources(kind, namespace, callback)
  local cmd = build_cmd_with_ns({ "get", kind, "-o", "json" }, namespace)
  run_async(cmd, parser.parse_resources, callback)
end

---Describe a resource
---@param kind string kubectl resource name (e.g., "pods", "deployments")
---@param name string
---@param namespace string
---@param callback fun(result: K8sResult)
function M.describe(kind, name, namespace, callback)
  local cmd = build_cmd_with_ns({ "describe", kind, name }, namespace)
  run_async(cmd, ok, callback)
end

---Get secret data with base64 decoded values
---@param name string
---@param namespace string
---@param callback fun(result: K8sResult)
function M.get_secret_data(name, namespace, callback)
  local cmd = build_cmd_with_ns({ "get", "secret", name, "-o", "json" }, namespace)
  run_async(cmd, function(output)
    local success, json = pcall(vim.json.decode, output)
    if not success then
      return { ok = false, error = "Failed to parse JSON" }
    end

    local data = json.data or {}
    local decoded = {}

    for key, value in pairs(data) do
      -- Base64 decode using Neovim's built-in function
      local decode_success, decoded_value = pcall(vim.base64.decode, value)
      if decode_success then
        decoded[key] = decoded_value
      else
        decoded[key] = value
      end
    end

    return ok(decoded)
  end, callback)
end

---Helper for void operations (returns nil on success)
---@param _ string
---@return K8sResult
local function void_result(_)
  return ok(nil)
end

---Delete a resource
---@param kind string kubectl resource name (e.g., "pods", "deployments")
---@param name string
---@param namespace string
---@param callback fun(result: K8sResult)
function M.delete(kind, name, namespace, callback)
  local cmd = build_cmd_with_ns({ "delete", kind, name }, namespace)
  run_async(cmd, void_result, callback)
end

---Scale a resource
---@param kind string kubectl resource name (e.g., "deployments")
---@param name string
---@param namespace string
---@param replicas number
---@param callback fun(result: K8sResult)
function M.scale(kind, name, namespace, replicas, callback)
  local cmd = build_cmd_with_ns({ "scale", kind, name, "--replicas=" .. tostring(replicas) }, namespace)
  run_async(cmd, void_result, callback)
end

---Restart a resource (rolling restart)
---@param kind string kubectl resource name (e.g., "deployments")
---@param name string
---@param namespace string
---@param callback fun(result: K8sResult)
function M.restart(kind, name, namespace, callback)
  local cmd = build_cmd_with_ns({ "rollout", "restart", kind, name }, namespace)
  run_async(cmd, void_result, callback)
end

---@class Job
---@field job_id number

-- Default shell command for auto-detection (bash preferred, fallback to sh)
local DEFAULT_SHELL = 'sh -c "[ -e /bin/bash ] && exec bash || exec sh"'

---@class ExecOpts
---@field on_exit? fun(job_id: number, exit_code: number, event: string) Callback when process exits
---@field tab_name? string Tab name to display

---Execute a command in a container
---@param pod string
---@param container string
---@param namespace string
---@param shell string|nil
---@param opts? ExecOpts
---@return K8sResult
function M.exec(pod, container, namespace, shell, opts)
  opts = opts or {}
  shell = shell or DEFAULT_SHELL
  local cmd = string.format("kubectl exec -it -n %s %s -c %s -- %s", namespace, pod, container, shell)
  local job_id = term_opener(cmd, { on_exit = opts.on_exit, tab_name = opts.tab_name })
  return ok({ job_id = job_id })
end

---@class LogOpts
---@field follow boolean|nil
---@field timestamps boolean|nil
---@field previous boolean|nil
---@field tab_name? string Tab name to display

---Get logs from a container
---@param pod string
---@param container string
---@param namespace string
---@param opts LogOpts
---@return K8sResult
function M.logs(pod, container, namespace, opts)
  opts = opts or {}
  local cmd_parts = { "kubectl", "logs", "-n", namespace, pod, "-c", container }

  if opts.follow then
    table.insert(cmd_parts, "-f")
  end
  if opts.timestamps then
    table.insert(cmd_parts, "--timestamps")
  end
  if opts.previous then
    table.insert(cmd_parts, "-p")
  end

  local cmd = table.concat(cmd_parts, " ")
  local job_id = term_opener(cmd, { tab_name = opts.tab_name })
  return ok({ job_id = job_id })
end

---Start port forwarding (runs as background job, not terminal)
---@param resource string
---@param namespace string
---@param local_port number
---@param remote_port number
---@return K8sResult
function M.port_forward(resource, namespace, local_port, remote_port)
  local cmd = { "kubectl", "port-forward", "-n", namespace, resource, string.format("%d:%d", local_port, remote_port) }
  local job_id = job_starter(cmd, {
    on_stderr = function(_, data)
      if data and data[1] and data[1] ~= "" then
        vim.schedule(function()
          vim.notify("Port forward error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end)
      end
    end,
  })
  if job_id <= 0 then
    return err("Failed to start port forward")
  end
  return ok({ job_id = job_id })
end

---Get list of available contexts
---@param callback fun(result: K8sResult)
function M.get_contexts(callback)
  local cmd = { "kubectl", "config", "get-contexts", "-o", "name" }
  run_async(cmd, parser.parse_contexts, callback)
end

---Switch to a different context
---@param name string
---@param callback fun(result: K8sResult)
function M.use_context(name, callback)
  local cmd = { "kubectl", "config", "use-context", name }
  run_async(cmd, void_result, callback)
end

---Get list of namespaces
---@param callback fun(result: K8sResult)
function M.get_namespaces(callback)
  local cmd = { "kubectl", "get", "namespaces", "-o", "json" }
  run_async(cmd, parser.parse_namespaces, callback)
end

return M
