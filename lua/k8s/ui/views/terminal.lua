--- terminal.lua - ターミナル管理モジュール（ログ/exec用タブ管理）

local M = {}

-- Default shell auto-detection command
local DEFAULT_SHELL_CMD = 'sh -c "[ -e /bin/bash ] && bash || sh"'

---Create tab name for terminal
---@param type "logs"|"exec" Terminal type
---@param pod_name string Pod name
---@param container? string Container name
---@return string name Tab name
function M.create_tab_name(type, pod_name, container)
  local name = "[" .. type .. "] " .. pod_name
  if container then
    name = name .. "/" .. container
  end
  return name
end

---Build kubectl logs command
---@param opts { pod: string, namespace: string, container?: string, previous?: boolean }
---@return string command kubectl logs command
function M.build_logs_command(opts)
  local parts = { "kubectl", "logs" }

  -- Namespace
  table.insert(parts, "-n")
  table.insert(parts, opts.namespace)

  -- Pod name
  table.insert(parts, opts.pod)

  -- Container
  if opts.container then
    table.insert(parts, "-c")
    table.insert(parts, opts.container)
  end

  -- Previous container logs
  if opts.previous then
    table.insert(parts, "-p")
  else
    -- Follow mode (only when not viewing previous logs)
    table.insert(parts, "-f")
  end

  -- Always include timestamps
  table.insert(parts, "--timestamps")

  return table.concat(parts, " ")
end

---Build kubectl exec command
---@param opts { pod: string, namespace: string, container?: string, shell?: string }
---@return string command kubectl exec command
function M.build_exec_command(opts)
  local parts = { "kubectl", "exec", "-it" }

  -- Namespace
  table.insert(parts, "-n")
  table.insert(parts, opts.namespace)

  -- Pod name
  table.insert(parts, opts.pod)

  -- Container
  if opts.container then
    table.insert(parts, "-c")
    table.insert(parts, opts.container)
  end

  -- Shell command
  table.insert(parts, "--")
  local shell = opts.shell or DEFAULT_SHELL_CMD
  table.insert(parts, shell)

  return table.concat(parts, " ")
end

---@class TerminalState
---@field job_id number|nil Job ID from termopen
---@field tab_id number|nil Tab page ID
---@field bufnr number|nil Buffer number
---@field type string Terminal type ("logs" or "exec")
---@field pod_name string Pod name

---Create initial terminal state
---@return TerminalState
function M.create_terminal_state()
  return {
    job_id = nil,
    tab_id = nil,
    bufnr = nil,
    type = "",
    pod_name = "",
  }
end

---@class ParsedTerminalType
---@field type string Terminal type
---@field pod_name string Pod name (may include container)

---Parse terminal type from tab name
---@param tab_name string Tab name
---@return ParsedTerminalType|nil
function M.parse_terminal_type(tab_name)
  local type, pod_name = tab_name:match("^%[(%w+)%]%s+(.+)$")
  if not type then
    return nil
  end

  return {
    type = type,
    pod_name = pod_name,
  }
end

---Check if terminal should auto-close on process exit
---@param type string Terminal type
---@return boolean
function M.should_auto_close(type)
  return type == "exec"
end

---Get shell command for exec
---@param custom_shell? string Custom shell command
---@return string
function M.get_shell_command(custom_shell)
  if custom_shell then
    return custom_shell
  end
  return DEFAULT_SHELL_CMD
end

---Create on_exit callback for terminal
---@param type string Terminal type
---@param close_fn function Function to close the tab/buffer
---@return function callback
function M.create_on_exit_callback(type, close_fn)
  return function(_, _, _)
    if M.should_auto_close(type) then
      -- Schedule to run after terminal is done
      vim.schedule(function()
        close_fn()
      end)
    end
  end
end

---Validate common required options (pod and namespace)
---@param opts table Options to validate
---@return boolean valid
---@return string|nil error Error message if invalid
local function validate_required_options(opts)
  if not opts.pod or opts.pod == "" then
    return false, "pod is required"
  end

  if not opts.namespace or opts.namespace == "" then
    return false, "namespace is required"
  end

  return true, nil
end

---Validate logs options
---@param opts table Options to validate
---@return boolean valid
---@return string|nil error Error message if invalid
function M.validate_logs_options(opts)
  return validate_required_options(opts)
end

---Validate exec options
---@param opts table Options to validate
---@return boolean valid
---@return string|nil error Error message if invalid
function M.validate_exec_options(opts)
  return validate_required_options(opts)
end

return M
