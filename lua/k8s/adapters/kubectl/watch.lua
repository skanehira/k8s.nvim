--- watch.lua - kubectl watch adapter

local M = {}

-- Default job starter
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

---Build kubectl watch command
---@param kind string
---@param namespace string
---@return string[]
local function build_watch_cmd(kind, namespace)
  local cmd = { "kubectl", "get", kind, "--watch", "--output-watch-events", "-o", "json" }

  if namespace == "All Namespaces" then
    table.insert(cmd, "--all-namespaces")
  else
    table.insert(cmd, "-n")
    table.insert(cmd, namespace)
  end

  return cmd
end

---@class WatchCallbacks
---@field on_event fun(event_type: string, resource: table) Called for each watch event
---@field on_error fun(error: string) Called on error
---@field on_exit fun() Called when watch process exits
---@field on_started? fun() Called when watch process starts

---Start watching resources
---@param kind string
---@param namespace string
---@param callbacks WatchCallbacks
---@return number|nil job_id
function M.watch(kind, namespace, callbacks)
  local cmd = build_watch_cmd(kind, namespace)
  local buffer = ""

  local job_id = job_starter(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      if not data then
        return
      end

      for _, line in ipairs(data) do
        if line ~= "" then
          -- Accumulate data (in case JSON is split across chunks)
          buffer = buffer .. line

          -- Try to parse complete JSON objects
          local success, event = pcall(vim.json.decode, buffer)
          if success and event and event.type and event.object then
            buffer = ""
            vim.schedule(function()
              callbacks.on_event(event.type, event.object)
            end)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] and data[1] ~= "" then
        vim.schedule(function()
          callbacks.on_error(table.concat(data, "\n"))
        end)
      end
    end,
    on_exit = function()
      vim.schedule(function()
        callbacks.on_exit()
      end)
    end,
  })

  if job_id <= 0 then
    return nil
  end

  -- Notify that watch has started
  if callbacks.on_started then
    vim.schedule(function()
      callbacks.on_started()
    end)
  end

  return job_id
end

---Stop watching
---@param job_id number
function M.stop(job_id)
  pcall(vim.fn.jobstop, job_id)
end

return M
