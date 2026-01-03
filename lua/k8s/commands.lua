--- commands.lua - CLI command handlers
--- Handles :K8s context and :K8s namespace commands

local M = {}

---Switch to a specific context
---@param context_name string|nil
function M.switch_context(context_name)
  local state = require("k8s.state")
  local notify = require("k8s.handlers.notify")

  if not context_name then
    vim.notify("Context name required. Usage: :K8s context <name>", vim.log.levels.WARN)
    return
  end

  local adapter = require("k8s.adapters.kubectl.adapter")
  adapter.use_context(context_name, function(result)
    vim.schedule(function()
      if result.ok then
        state.set_context(context_name)
        notify.info("Switched to context: " .. context_name)
      else
        notify.error("Failed to switch context: " .. (result.error or "Unknown error"))
      end
    end)
  end)
end

---Switch to a specific namespace
---@param namespace_name string|nil
function M.switch_namespace(namespace_name)
  local state = require("k8s.state")
  local notify = require("k8s.handlers.notify")
  local watcher = require("k8s.handlers.watcher")

  if not namespace_name then
    vim.notify("Namespace name required. Usage: :K8s namespace <name>", vim.log.levels.WARN)
    return
  end

  -- Convert CLI "all" to internal "All Namespaces"
  local namespace = namespace_name == "all" and "All Namespaces" or namespace_name

  state.set_namespace(namespace)
  notify.info("Switched to namespace: " .. namespace_name)

  -- Restart watcher with new namespace (event handling is done inside watcher.lua)
  watcher.restart({})
end

return M
