--- plugin.lua - プラグインコマンド補完

local M = {}

-- Subcommands for completion
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
