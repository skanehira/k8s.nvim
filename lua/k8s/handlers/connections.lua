--- connections.lua - ポートフォワード接続を管理

local M = {}

---@class Connection
---@field job_id number
---@field resource string
---@field namespace string
---@field local_port number
---@field remote_port number

---@type Connection[]
local connections = {}

---Add a new connection
---@param opts table
---@return Connection
function M.add(opts)
  local conn = {
    job_id = opts.job_id,
    resource = opts.resource,
    namespace = opts.namespace,
    local_port = opts.local_port,
    remote_port = opts.remote_port,
  }
  table.insert(connections, conn)
  return conn
end

---Remove a connection by job_id
---@param job_id number
---@return boolean
function M.remove(job_id)
  for i, conn in ipairs(connections) do
    if conn.job_id == job_id then
      -- Stop the job and wait for it to terminate
      pcall(vim.fn.jobstop, job_id)
      pcall(vim.fn.jobwait, { job_id }, 1000)
      table.remove(connections, i)
      return true
    end
  end
  return false
end

---Get a connection by job_id
---@param job_id number
---@return Connection|nil
function M.get(job_id)
  for _, conn in ipairs(connections) do
    if conn.job_id == job_id then
      return conn
    end
  end
  return nil
end

---Get all connections
---@return Connection[]
function M.get_all()
  return connections
end

---Get connection count
---@return number
function M.count()
  return #connections
end

---Clear all connections (stops all jobs)
function M.clear()
  for _, conn in ipairs(connections) do
    pcall(vim.fn.jobstop, conn.job_id)
  end
  connections = {}
end

---Stop a connection by index (1-based)
---@param index number
---@return boolean
function M.stop_at(index)
  if index < 1 or index > #connections then
    return false
  end
  local conn = connections[index]
  return M.remove(conn.job_id)
end

---Reset connections state (for testing)
function M._reset()
  connections = {}
end

return M
