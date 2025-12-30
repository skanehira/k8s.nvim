--- plugin.lua - プラグインコマンド定義ヘルパー

local M = {}

-- Subcommands
local subcommands = {
  "open",
  "close",
  "pods",
  "deployments",
  "services",
  "configmaps",
  "secrets",
  "nodes",
  "namespaces",
  "portforwards",
  "context",
  "namespace",
}

-- Command to kind mapping
local command_to_kind = {
  pods = "Pod",
  deployments = "Deployment",
  services = "Service",
  configmaps = "ConfigMap",
  secrets = "Secret",
  nodes = "Node",
  namespaces = "Namespace",
}

---Get command definitions
---@return table[]
function M.get_commands()
  return {
    {
      name = "K8s",
      nargs = "*",
      complete = "customlist,v:lua.require'k8s.plugin'.complete",
      desc = "Kubernetes resource manager",
    },
  }
end

---Get plug mappings
---@return table[]
function M.get_plug_mappings()
  return {
    {
      name = "<Plug>(k8s-toggle)",
      action = "toggle",
      desc = "Toggle k8s.nvim",
    },
    {
      name = "<Plug>(k8s-open)",
      action = "open",
      desc = "Open k8s.nvim",
    },
    {
      name = "<Plug>(k8s-close)",
      action = "close",
      desc = "Close k8s.nvim",
    },
  }
end

---Get command completions
---@return string[]
function M.get_command_completions()
  return subcommands
end

---Parse command
---@param arg string
---@return string action
---@return table|nil args
function M.parse_command(arg)
  if not arg or arg == "" then
    return "toggle", nil
  end

  local parts = vim.split(arg, " ")
  local cmd = parts[1]:lower()

  if cmd == "open" then
    return "open", nil
  elseif cmd == "close" then
    return "close", nil
  elseif cmd == "context" then
    return "context", { name = parts[2] }
  elseif cmd == "namespace" then
    return "namespace", { name = parts[2] }
  else
    local kind = command_to_kind[cmd]
    if kind then
      return "open_resource", { kind = kind }
    end
  end

  return "toggle", nil
end

---Get subcommand list
---@return string[]
function M.get_subcommand_list()
  return subcommands
end

---Completion function
---@param lead string
---@return string[]
function M.complete(lead)
  local results = {}
  for _, cmd in ipairs(subcommands) do
    if cmd:find("^" .. lead) then
      table.insert(results, cmd)
    end
  end
  return results
end

return M
