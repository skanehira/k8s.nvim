--- plugin/k8s.lua - プラグインエントリポイント

if vim.g.loaded_k8s then
  return
end
vim.g.loaded_k8s = true

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
  "applications",
  "portforwards",
  "context",
  "namespace",
}

---Completion function
---@param lead string
---@return string[]
local function complete(lead)
  local results = {}
  for _, cmd in ipairs(subcommands) do
    if cmd:find("^" .. lead) then
      table.insert(results, cmd)
    end
  end
  return results
end

-- Create user command
vim.api.nvim_create_user_command("K8s", function(opts)
  local k8s = require("k8s")
  local cmd, args = k8s.parse_command_args(opts.fargs)

  if cmd == "toggle" then
    k8s.toggle()
  elseif cmd == "open" then
    k8s.open()
  elseif cmd == "close" then
    k8s.close()
  elseif cmd == "open_resource" and args then
    k8s.open({ kind = args.kind })
  elseif cmd == "context" and args then
    k8s.switch_context(args.name)
  elseif cmd == "namespace" and args then
    k8s.switch_namespace(args.name)
  elseif cmd == "portforwards" then
    k8s.show_port_forwards()
  end
end, {
  nargs = "*",
  complete = function(_, line)
    local args = vim.split(line, "%s+")
    local lead = args[#args] or ""
    return complete(lead)
  end,
  desc = "Kubernetes resource manager",
})

-- Create Plug mappings
vim.keymap.set("n", "<Plug>(k8s-toggle)", function()
  require("k8s").toggle()
end, { desc = "Toggle k8s.nvim" })

vim.keymap.set("n", "<Plug>(k8s-open)", function()
  require("k8s").open()
end, { desc = "Open k8s.nvim" })

vim.keymap.set("n", "<Plug>(k8s-close)", function()
  require("k8s").close()
end, { desc = "Close k8s.nvim" })
