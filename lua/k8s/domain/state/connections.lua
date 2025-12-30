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

---Clear all connections
function M.clear()
  connections = {}
end

---Check if a connection exists
---@param job_id number
---@return boolean
function M.exists(job_id)
  return M.get(job_id) ~= nil
end

return M
